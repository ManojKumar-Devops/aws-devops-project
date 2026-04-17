# 🚀 AWS DevOps Project — Production-Grade Microservice on EKS

A complete, advanced-level AWS DevOps project featuring a containerized Python microservice deployed on Amazon EKS with a fully automated CI/CD pipeline, infrastructure-as-code, and observability stack.

---

## 📐 Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                          GitHub Actions CI/CD                        │
│  Push → Lint → Test → Build → Scan → Deploy Staging → Deploy Prod   │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
          ┌────────────────▼─────────────────┐
          │           Amazon ECR              │
          │     (Docker Image Registry)       │
          └────────────────┬─────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────────┐
│                      Amazon EKS Cluster                              │
│                                                                      │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────────────────┐   │
│  │  Namespace  │   │  Namespace  │   │       Namespace         │   │
│  │  production │   │   staging   │   │       monitoring        │   │
│  │             │   │             │   │                         │   │
│  │ ┌─────────┐ │   │ ┌─────────┐ │   │ ┌──────────────────┐   │   │
│  │ │microapp │ │   │ │microapp │ │   │ │ Prometheus Stack │   │   │
│  │ │ x3 pods │ │   │ │ x2 pods │ │   │ │    + Grafana     │   │   │
│  │ └────┬────┘ │   │ └────┬────┘ │   │ └──────────────────┘   │   │
│  │      │ HPA  │   │      │ HPA  │   └─────────────────────────┘   │
│  └──────┼──────┘   └──────┼──────┘                                 │
│         │                 │                                         │
│  ┌──────▼─────────────────▼──────┐                                 │
│  │     AWS Load Balancer (ALB)   │                                 │
│  └──────────────────────────────-┘                                 │
└──────────────────────────────────────────────────────────────────────┘
                           │
          ┌────────────────▼─────────────────┐
          │        Amazon RDS PostgreSQL      │
          │       (Private subnet, encrypted) │
          └───────────────────────────────────┘
```

---

## 📁 Project Structure

```
aws-devops-project/
├── .github/
│   └── workflows/
│       ├── cicd.yml            # Main CI/CD pipeline
│       ├── terraform.yml       # Infrastructure pipeline
│       └── nightly-scan.yml    # Security scanning
├── app/
│   ├── src/
│   │   └── app.py              # Flask microservice
│   ├── tests/
│   │   └── test_app.py         # Unit tests
│   └── requirements.txt
├── docker/
├── k8s/
│   ├── base/                   # Shared Kubernetes manifests
│   │   ├── deployment.yaml
│   │   ├── service.yaml        # Service, HPA, RBAC, PDB
│   │   ├── ingress.yaml
│   │   └── kustomization.yaml
│   └── overlays/
│       ├── dev/
│       ├── staging/
│       └── prod/               # Kustomize per-environment patches
├── terraform/
│   ├── main.tf                 # VPC, EKS, ECR, RDS
│   ├── variables.tf
│   ├── outputs.tf
│   └── environments/
│       ├── dev/terraform.tfvars
│       ├── staging/terraform.tfvars
│       └── prod/terraform.tfvars
├── helm/
│   └── microapp/               # Helm chart (alternative to Kustomize)
│       ├── Chart.yaml
│       └── values.yaml
├── monitoring/
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── alerts.yml          # Alerting rules
│   └── grafana/
├── scripts/
│   ├── bootstrap.sh            # One-time setup script
│   ├── rollback.sh             # Emergency rollback
│   ├── port-forward.sh         # Local debugging
│   └── init-db.sql             # Database schema
├── Dockerfile                  # Multi-stage Docker build
├── docker-compose.yml          # Local development stack
└── README.md
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Application** | Python 3.11, Flask, Gunicorn |
| **Database** | PostgreSQL 15 (RDS) |
| **Containerization** | Docker (multi-stage builds) |
| **Orchestration** | Kubernetes 1.29 (EKS) |
| **Config Management** | Kustomize + Helm |
| **Infrastructure** | Terraform (IaC) |
| **CI/CD** | GitHub Actions |
| **Container Registry** | Amazon ECR |
| **Load Balancing** | AWS ALB + ALB Ingress Controller |
| **Autoscaling** | HPA (CPU + Memory metrics) |
| **Monitoring** | Prometheus + Grafana |
| **Security Scanning** | Trivy, Bandit, Safety, Hadolint |

---

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Install required tools
brew install awscli terraform kubectl helm git docker
# or on Linux:
# curl -fsSL https://get.docker.com | sh
# snap install kubectl --classic
# snap install helm --classic
```

### 2. Configure AWS

```bash
aws configure
# AWS Access Key ID: <your-key>
# AWS Secret Access Key: <your-secret>
# Default region: us-east-1
# Output format: json
```

### 3. Clone & Bootstrap

```bash
git clone https://github.com/YOUR_USERNAME/aws-devops-project.git
cd aws-devops-project

# Run one-time bootstrap (creates AWS infra + pushes to GitHub)
./scripts/bootstrap.sh dev https://github.com/YOUR_USERNAME/aws-devops-project.git
```

### 4. Local Development

```bash
# Start full stack locally
docker-compose up -d

# API:        http://localhost:5000
# Grafana:    http://localhost:3000  (admin/admin)
# Prometheus: http://localhost:9090

# Run tests
cd app && python -m pytest tests/ -v --cov=src
```

---

## 🔄 CI/CD Pipeline Flow

```
git push origin develop
     │
     ▼
┌─────────────┐    ┌─────────────┐    ┌───────────────┐    ┌─────────────────┐
│   Lint &    │───▶│    Unit &   │───▶│  Build &      │───▶│ Deploy Staging  │
│  Security   │    │  Integration│    │  Push to ECR  │    │ + Smoke Tests   │
│   Scan      │    │   Tests     │    │ + Trivy Scan  │    │                 │
└─────────────┘    └─────────────┘    └───────────────┘    └─────────────────┘

git push origin main (or PR merge)
     │
     ▼
[Same lint/test/build] ──▶ Deploy Production ──▶ Smoke Tests ──▶ GitHub Release
                                  │ (on failure)
                                  └──▶ Auto Rollback + Slack Alert
```

---

## 🔐 GitHub Secrets Required

Add these in **Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `TF_STATE_BUCKET` | S3 bucket name for Terraform state |
| `SLACK_BOT_TOKEN` | (Optional) Slack notifications |
| `SLACK_CHANNEL_ID` | (Optional) Slack channel |

---

## 🌍 Deploy to Environments

```bash
# Deploy to staging (push to develop)
git checkout develop
git push origin develop

# Deploy to production (merge to main)
git checkout main
git merge develop
git push origin main

# Manual rollback
./scripts/rollback.sh production
./scripts/rollback.sh production 3   # Roll back to specific revision

# Port-forward for debugging
./scripts/port-forward.sh staging
```

---

## 📊 Monitoring & Alerts

Alerts are configured for:
- **AppHighErrorRate** — >5% HTTP 5xx errors for 2 minutes
- **AppHighLatency** — p95 latency >1s for 3 minutes
- **AppDown** — Service unreachable for 1 minute
- **PodCrashLooping** — >3 restarts in 15 minutes
- **HighCPUUsage** — >85% CPU limit for 10 minutes
- **HighMemoryUsage** — >90% memory limit for 5 minutes

Access Grafana dashboard:
```bash
./scripts/port-forward.sh production
open http://localhost:3001   # admin / admin123
```

---

## 🏗️ Infrastructure Management

```bash
# Plan infrastructure changes
cd terraform
terraform plan -var-file=environments/prod/terraform.tfvars

# Apply changes
terraform apply -var-file=environments/prod/terraform.tfvars

# Or use the GitHub Actions Terraform workflow:
# Actions → Terraform Infrastructure → Run workflow → select env + action
```

---

## 🔒 Security Features

- **Non-root container** — app runs as UID 1000
- **Read-only root filesystem** — via securityContext
- **Image vulnerability scanning** — Trivy on every build (CRITICAL/HIGH)
- **Dependency scanning** — Bandit (SAST) + Safety (CVE) in CI
- **Dockerfile linting** — Hadolint on every PR
- **ECR scanning** — Automated scan-on-push + nightly checks
- **Pod Security Standards** — Restricted via securityContext
- **Network isolation** — RDS in private subnets, security groups
- **Secrets management** — AWS Secrets Manager for DB credentials
- **RBAC** — Least-privilege ServiceAccount per workload

---

## 📋 API Reference

| Method | Endpoint | Description |
|---|---|---|
| GET | `/health` | Liveness check |
| GET | `/ready` | Readiness check (DB ping) |
| GET | `/metrics` | Prometheus metrics |
| GET | `/api/v1/items` | List all items |
| POST | `/api/v1/items` | Create item |
| GET | `/api/v1/items/:id` | Get item by ID |
| PUT | `/api/v1/items/:id` | Update item |
| DELETE | `/api/v1/items/:id` | Delete item |

---

## 📝 License

MIT — see [LICENSE](LICENSE)
