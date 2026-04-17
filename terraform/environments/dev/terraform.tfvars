environment         = "dev"
aws_region          = "us-east-1"
project_name        = "microapp"
cluster_name        = "microapp-eks-dev"
kubernetes_version  = "1.32"

vpc_cidr             = "10.2.0.0/16"
private_subnet_cidrs = ["10.2.1.0/24", "10.2.2.0/24"]
public_subnet_cidrs  = ["10.2.101.0/24", "10.2.102.0/24"]

node_instance_types = ["t3.small"]
node_min_size       = 1
node_max_size       = 3
node_desired_size   = 1

db_instance_class = "db.t3.micro"
