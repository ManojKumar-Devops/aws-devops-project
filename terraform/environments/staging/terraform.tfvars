environment         = "staging"
aws_region          = "us-east-1"
project_name        = "microapp"
cluster_name        = "microapp-eks-staging"
kubernetes_version  = "1.29"

vpc_cidr             = "10.1.0.0/16"
private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
public_subnet_cidrs  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]

node_instance_types = ["t3.medium"]
node_min_size       = 2
node_max_size       = 6
node_desired_size   = 2

db_instance_class = "db.t3.micro"
