environment         = "production"
aws_region          = "us-east-1"
project_name        = "microapp"
cluster_name        = "microapp-eks-prod"
kubernetes_version  = "1.32"

vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

node_instance_types = ["t3.large"]
node_min_size       = 3
node_max_size       = 10
node_desired_size   = 3

db_instance_class = "db.t3.small"
