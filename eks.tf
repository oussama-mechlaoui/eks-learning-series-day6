# ------------------------------------------
# EKS Cluster and Managed NodeGroups
# ------------------------------------------

module "eks_blueprints" {
  
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.24.0"

  cluster_name    = local.name
  enable_irsa     = true

  # EKS Cluster VPC and Subnet mandatory config
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
  public_subnet_ids  = module.vpc.public_subnets

  # EKS CONTROL PLANE VARIABLES
  cluster_version = local.cluster_version

  # List of Additional roles admin in the cluster
  # Comment this section if you ARE NOTE at an AWS Event, as the TeamRole won't exist on your site, or replace with any valid role you want
  #map_roles = [
  #  {
  #    rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/TeamRole"
  #    username = "ops-role" # The user name within Kubernetes to map to the IAM role
  #    groups   = ["system:masters"] # A list of groups within Kubernetes to which the role is mapped; Checkout K8s Role and Rolebindings
  #  }
  #]

  # EKS MANAGED NODE GROUPS
  managed_node_groups = {
    managed_ng_spot_blueprints = {
      remote_access = true
      ec2_ssh_key = var.ec2_key
      node_group_name = "managed_ng_blueprints"
      capacity_type   = "SPOT"
      instance_types  = ["m5.large"] // Instances with same specs for memory and CPU
    
      # Node Group network configuration
      subnet_type = "private" # public or private - Default uses the private subnets used in control plane if you don't pass the "subnet_ids"
      subnet_ids  = []        # Defaults to private subnet-ids used by EKS Control plane. Define your private/public subnets list with comma separated subnet_ids  = ['subnet1','subnet2','subnet3']
    
      min_size = 3// Scale-down to zero nodes when no workloads are running, useful for pre-production environments
      max_size= 3
      desired_size= 3
          
      # This is so cluster autoscaler can identify which node (using ASGs tags) to scale-down to zero nodes
      additional_tags = {
            "k8s.io/cluster-autoscaler/node-template/label/eks.amazonaws.com/capacityType" = "SPOT"
            "k8s.io/cluster-autoscaler/node-template/label/eks/node_group_name"            = "mng-spot-2vcpu-8mem"
            "auto-delete"                                                                  = "no"
            "auto-stop"                                                                    = "no"
      }
    }
  }
    
  tags = local.tags
}

# ------------------------------------------
# EKS/K8S add-ons
# ------------------------------------------

module "eks_blueprints_kubernetes_addons" {
  depends_on = [module.eks_blueprints]
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.24.0"
  eks_cluster_id       = module.eks_blueprints.eks_cluster_id
  eks_cluster_endpoint = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider    = module.eks_blueprints.oidc_provider
  eks_cluster_version  = module.eks_blueprints.eks_cluster_version

  enable_amazon_eks_vpc_cni = true
  amazon_eks_vpc_cni_config = {
    addon_version     = data.aws_eks_addon_version.latest["vpc-cni"].version
    resolve_conflicts = "OVERWRITE"
  }

  enable_amazon_eks_kube_proxy = true
  amazon_eks_kube_proxy_config = {
    addon_version     = data.aws_eks_addon_version.latest["kube-proxy"].version
    resolve_conflicts = "OVERWRITE"
  }

  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller_helm_config = {
    set_values = [
      {
        name  = "vpcId"
        value = module.vpc.vpc_id
      },
      {
        name  = "podDisruptionBudget.maxUnavailable"
        value = 1
      },
    ]
  }
  
  enable_amazon_eks_aws_ebs_csi_driver = true
  amazon_eks_aws_ebs_csi_driver_config = {
    resolve_conflicts = "OVERWRITE"
  }
  
}

resource "aws_cloud9_environment_ec2" "example" {
  instance_type = "m5.large"
  name          = "terraform-blueprints-env"
  subnet_id = module.vpc.public_subnets[0]
  owner_arn = data.aws_caller_identity.current.arn
}