resource "aws_ebs_volume" "existing" {
  availability_zone    = "us-east-1a"
  size                 = 4
  type                 = "gp3"
  iops                 = 3000
  encrypted            = false
  multi_attach_enabled = false

  tags = {
    "Name"                                      = "eks-express-cluster-dynamic-pvc-9cd25a4f-25e2-42fc-a012-2ec00028995b"
    "KubernetesCluster"                         = "eks-express-cluster"
    "CSIVolumeName"                             = "pvc-9cd25a4f-25e2-42fc-a012-2ec00028995b"
    "ebs.csi.aws.com/cluster"                   = "true"
    "ebs.csi.aws.com/cluster-name"              = "eks-express-cluster"
    "kubernetes.io/cluster/eks-express-cluster" = "owned"
    "kubernetes.io/created-for/pv/name"         = "pvc-9cd25a4f-25e2-42fc-a012-2ec00028995b"
    "kubernetes.io/created-for/pvc/name"        = "ebs-claim"
    "kubernetes.io/created-for/pvc/namespace"   = "default"
  }
}

output "volume_id" {
  description = "ID of the EBS volume managed independently from the cluster."
  value       = aws_ebs_volume.existing.id
}
