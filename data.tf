# Find the user currently in use by AWS
data "aws_caller_identity" "current" {}

# Region in which to deploy the solution
data "aws_region" "current" {}

# Availability zones to use in our solution
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks_blueprints.eks_cluster_id
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks_blueprints.eks_cluster_id
}

data "aws_eks_addon_version" "latest" {
  for_each = toset(["kube-proxy", "vpc-cni"])

  addon_name         = each.value
  kubernetes_version = module.eks_blueprints.eks_cluster_version
  most_recent        = true
}
