#!/usr/bin/env bash
# =============================================================================
#  bootstrap.sh — One-time AWS + GitHub project setup
#  Usage: ./scripts/bootstrap.sh <environment> <github-repo-url>
#  Example: ./scripts/bootstrap.sh dev https://github.com/yourname/aws-devops-project.git
# =============================================================================
set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ─── Args & Config ───────────────────────────────────────────────────────────
ENVIRONMENT="${1:-dev}"
GITHUB_REPO="${2:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="microapp"
TERRAFORM_STATE_BUCKET="${PROJECT_NAME}-tfstate-$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'ACCOUNT')"
TERRAFORM_LOCK_TABLE="${PROJECT_NAME}-tfstate-lock"

echo -e "\n${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   AWS DevOps Bootstrap — ${ENVIRONMENT^^} Environment          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}\n"

# ─── Prerequisites ───────────────────────────────────────────────────────────
check_prerequisites() {
  info "Checking prerequisites..."
  local missing=()
  for cmd in aws terraform kubectl helm git docker; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  [ ${#missing[@]} -gt 0 ] && error "Missing tools: ${missing[*]}. Please install them first."
  success "All prerequisites satisfied"
}

# ─── Terraform State Backend ─────────────────────────────────────────────────
setup_terraform_backend() {
  info "Setting up Terraform S3 backend..."

  # Create S3 bucket for state
  if ! aws s3api head-bucket --bucket "$TERRAFORM_STATE_BUCKET" 2>/dev/null; then
    aws s3api create-bucket \
      --bucket "$TERRAFORM_STATE_BUCKET" \
      --region "$AWS_REGION" \
      $( [[ "$AWS_REGION" != "us-east-1" ]] && echo "--create-bucket-configuration LocationConstraint=$AWS_REGION" )
    aws s3api put-bucket-versioning \
      --bucket "$TERRAFORM_STATE_BUCKET" \
      --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption \
      --bucket "$TERRAFORM_STATE_BUCKET" \
      --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
    aws s3api put-public-access-block \
      --bucket "$TERRAFORM_STATE_BUCKET" \
      --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    success "Created S3 state bucket: $TERRAFORM_STATE_BUCKET"
  else
    success "S3 state bucket already exists: $TERRAFORM_STATE_BUCKET"
  fi

  # Create DynamoDB table for state locking
  if ! aws dynamodb describe-table --table-name "$TERRAFORM_LOCK_TABLE" --region "$AWS_REGION" &>/dev/null; then
    aws dynamodb create-table \
      --table-name "$TERRAFORM_LOCK_TABLE" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region "$AWS_REGION"
    success "Created DynamoDB lock table: $TERRAFORM_LOCK_TABLE"
  else
    success "DynamoDB lock table already exists"
  fi
}

# ─── Terraform Init & Apply ───────────────────────────────────────────────────
run_terraform() {
  info "Initializing Terraform for environment: $ENVIRONMENT..."
  cd terraform
  terraform init \
    -backend-config="bucket=$TERRAFORM_STATE_BUCKET" \
    -backend-config="key=${PROJECT_NAME}/${ENVIRONMENT}/terraform.tfstate" \
    -backend-config="region=$AWS_REGION" \
    -backend-config="dynamodb_table=$TERRAFORM_LOCK_TABLE"

  info "Planning Terraform..."
  terraform plan \
    -var-file="environments/${ENVIRONMENT}/terraform.tfvars" \
    -out="${ENVIRONMENT}.tfplan"

  read -rp "$(echo -e "${YELLOW}Apply Terraform plan? (yes/no): ${NC}")" confirm
  if [[ "$confirm" == "yes" ]]; then
    terraform apply "${ENVIRONMENT}.tfplan"
    success "Terraform applied successfully"
  else
    warn "Terraform apply skipped"
  fi
  cd ..
}

# ─── Configure kubectl ────────────────────────────────────────────────────────
configure_kubectl() {
  info "Configuring kubectl..."
  CLUSTER_NAME=$(terraform -chdir=terraform output -raw eks_cluster_name 2>/dev/null || echo "${PROJECT_NAME}-eks-${ENVIRONMENT}")
  aws eks update-kubeconfig \
    --name "$CLUSTER_NAME" \
    --region "$AWS_REGION"
  kubectl get nodes
  success "kubectl configured for cluster: $CLUSTER_NAME"
}

# ─── Create Kubernetes Namespaces ─────────────────────────────────────────────
setup_k8s_namespaces() {
  info "Creating Kubernetes namespaces..."
  for ns in production staging development monitoring; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace "$ns" environment="$ns" --overwrite
  done
  success "Namespaces created"
}

# ─── Install Cluster Add-ons via Helm ─────────────────────────────────────────
install_addons() {
  info "Installing cluster add-ons..."

  # AWS Load Balancer Controller
  helm repo add eks https://aws.github.io/eks-charts --force-update
  helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName="$(terraform -chdir=terraform output -raw eks_cluster_name 2>/dev/null || echo 'microapp-eks')" \
    --set serviceAccount.create=true \
    --wait

  # metrics-server (required for HPA)
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update
  helm upgrade --install metrics-server metrics-server/metrics-server \
    -n kube-system --wait

  # Prometheus + Grafana stack
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
  helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    -n monitoring \
    --set grafana.adminPassword=admin123 \
    --wait

  success "Cluster add-ons installed"
}

# ─── Git Initialization & GitHub Push ────────────────────────────────────────
setup_github() {
  info "Setting up Git repository..."
  
  # Init if not already
  if [ ! -d ".git" ]; then
    git init
    git branch -M main
  fi

  # Create .gitignore
  cat > .gitignore <<'GITIGNORE'
# Terraform
*.tfstate
*.tfstate.backup
*.tfplan
.terraform/
.terraform.lock.hcl
terraform/environments/*/backend.tf

# Python
__pycache__/
*.py[cod]
*.egg-info/
.pytest_cache/
.coverage
coverage.xml
htmlcov/
dist/
build/
venv/
.env

# Docker
.docker/

# IDE
.vscode/
.idea/
*.swp

# OS
.DS_Store
Thumbs.db

# Secrets (never commit these)
*.pem
*.key
secrets/
.env.local
GITIGNORE

  git add -A
  git commit -m "feat: initial AWS DevOps project with Docker, Kubernetes, and CI/CD pipeline

- Multi-stage Dockerfile with security best practices
- Flask microservice with PostgreSQL, health/readiness probes, Prometheus metrics
- Kubernetes manifests: Deployment, Service, Ingress, HPA, PDB, RBAC
- Kustomize overlays for dev/staging/production
- Helm chart for flexible deployment
- Terraform for full AWS infra: VPC, EKS, ECR, RDS
- GitHub Actions CI/CD: lint, test, build, scan, deploy, rollback
- Nightly security scanning workflow
- Prometheus alerting rules + Grafana monitoring
- Docker Compose for local development"

  if [[ -n "$GITHUB_REPO" ]]; then
    git remote add origin "$GITHUB_REPO" 2>/dev/null || git remote set-url origin "$GITHUB_REPO"
    git push -u origin main
    success "Code pushed to: $GITHUB_REPO"
  else
    warn "No GitHub URL provided — skipping push. Run: git remote add origin <url> && git push -u origin main"
  fi
}

# ─── Print Summary ────────────────────────────────────────────────────────────
print_summary() {
  echo -e "\n${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║              Bootstrap Complete! 🚀                  ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
  echo -e ""
  echo -e "  ${CYAN}Next Steps:${NC}"
  echo -e "  1. Add GitHub Secrets (Settings → Secrets → Actions):"
  echo -e "     • AWS_ACCESS_KEY_ID"
  echo -e "     • AWS_SECRET_ACCESS_KEY"
  echo -e "     • SLACK_BOT_TOKEN (optional)"
  echo -e "     • SLACK_CHANNEL_ID (optional)"
  echo -e ""
  echo -e "  2. Push to 'develop' branch → deploys to ${YELLOW}staging${NC}"
  echo -e "  3. Merge to 'main' branch   → deploys to ${GREEN}production${NC}"
  echo -e ""
  echo -e "  4. Local dev: ${CYAN}docker-compose up${NC}"
  echo -e "  5. View metrics: ${CYAN}http://localhost:3000${NC} (Grafana)"
  echo -e ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  check_prerequisites
  setup_terraform_backend
  run_terraform
  configure_kubectl
  setup_k8s_namespaces
  install_addons
  setup_github
  print_summary
}

main "$@"
