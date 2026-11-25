#!/bin/bash

set -euo pipefail

function enableKubernetesClusterConnection() {
    aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"
}

function installkarpenterCustomResourceDefinitions() {
kubectl apply --server-side -f \
    "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.15.3/pkg/apis/crds/karpenter.sh_nodepools.yaml"
kubectl apply --server-side -f \
    "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.15.3/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml"
kubectl apply --server-side -f \
    "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.15.3/pkg/apis/crds/karpenter.sh_nodeclaims.yaml"

}

enableKubernetesClusterConnection
installkarpenterCustomResourceDefinitions