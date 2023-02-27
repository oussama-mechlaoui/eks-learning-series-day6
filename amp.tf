# ------------------------------------------
# AMP Resources
# ------------------------------------------

resource "aws_prometheus_workspace" "amp" {
  alias = "amp-kube-prometheus"
}

# ------------------------------------------
# AMP Ingest Permissions
# ------------------------------------------

data "aws_iam_policy_document" "ingest" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "aps:GetLabels",
      "aps:GetMetricMetadata",
      "aps:GetSeries",
      "aps:RemoteWrite",
    ]
  }
}

resource "aws_iam_policy" "ingest" {

  name        = format("%s-%s", "amp-ingest", module.eks_blueprints.eks_cluster_id)
  description = "Set up the permission policy that grants ingest (remote write) permissions for AMP workspace"
  policy      = data.aws_iam_policy_document.ingest.json
}

module "irsa_amp_ingest" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/irsa?ref=v4.24.0"

  create_kubernetes_namespace = true
  kubernetes_namespace        = "kube-prometheus-stack"

  kubernetes_service_account    = "prometheus-sa"
  irsa_iam_policies             = [aws_iam_policy.ingest.arn]
  eks_cluster_id                = module.eks_blueprints.eks_cluster_id
  eks_oidc_provider_arn         = module.eks_blueprints.eks_oidc_provider_arn
}

# ------------------------------------------
# AMP Query Permissions
# ------------------------------------------

data "aws_iam_policy_document" "query" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "aps:GetLabels",
      "aps:GetMetricMetadata",
      "aps:GetSeries",
      "aps:QueryMetrics",
    ]
  }
}

resource "aws_iam_policy" "query" {
  name        = format("%s-%s", "amp-query", module.eks_blueprints.eks_cluster_id)
  description = "Set up the permission policy that grants query permissions for AMP workspace"
  policy      = data.aws_iam_policy_document.query.json
}

module "irsa_amp_query" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/irsa?ref=v4.24.0"

  create_kubernetes_namespace = false
  kubernetes_namespace        = "kube-prometheus-stack"

  kubernetes_service_account    = "grafana-sa"
  irsa_iam_policies             = [aws_iam_policy.query.arn]
  eks_cluster_id                = module.eks_blueprints.eks_cluster_id
  eks_oidc_provider_arn         = module.eks_blueprints.eks_oidc_provider_arn
}

module "helm_addon" {
  depends_on = [module.eks_blueprints, module.eks_blueprints_kubernetes_addons]
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons/helm-addon?ref=v4.24.0"
  helm_config = {
    name       = "kube-prometheus-stack"

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "kube-prometheus-stack"
  create_namespace = "false"
  
  values = [
    templatefile("${path.root}/templates/kube-prom-values.yaml.tpl",
    {
      url: aws_prometheus_workspace.amp.prometheus_endpoint
      region: data.aws_region.current.name
      prometheus_iam: module.irsa_amp_ingest.irsa_iam_role_arn
      grafana_iam: module.irsa_amp_query.irsa_iam_role_arn
    }
    )
  ]
  }
  addon_context = {}
  
}