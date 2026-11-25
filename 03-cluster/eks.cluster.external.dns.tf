resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.23.0"
  namespace = "external-dns"
  create_namespace = true

  set = [
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.external_dns.arn      
    },
    {
      name  = "policy"
      value = "sync"
    },
    {
      name  = "provider"
      value = "aws"
    },
    {
      name  = "aws.zoneType"
      value = "public"
    },
    {
      name  = "domainFilters[0]"
      value = "jovando.com.br"
    },
    {
      name  = "registry"
      value = "txt"
    },
    {
      name  = "txtOwnerId"
      value = "eks-cluster"
    }
  ]

  depends_on = [
  aws_iam_role_policy_attachment.external_dns,
  aws_eks_node_group.this,
  aws_eks_access_policy_association.bash_user]
  
  force_update = true
  cleanup_on_fail = true
}

