#!/bin/bash

set -e

BASE_DIR="/home/kali/kenerry/NSSE-IAC"

echo "════════════════════════════════════════════════════════════"
echo "🔴 DESTRUIÇÃO COMPLETA - NSSE-IAC"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Este script irá destruir TODOS os recursos em ordem:"
echo "  1️⃣  Cluster EKS (e dependências)"
echo "  2️⃣  Networking (VPC, Subnets, etc)"
echo ""
read -p "⚠️  Tem certeza? (s/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Operação cancelada"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "FASE 1️⃣ : LIMPEZA PRÉ-DESTROY (Cluster)"
echo "════════════════════════════════════════════════════════════"
echo ""

cd "$BASE_DIR/cluster"

# Deletar Ingress
echo "🗑️  Deletando Ingress resources..."
kubectl delete ingress --all --all-namespaces 2>/dev/null || echo "   ℹ️  Nenhum Ingress encontrado"
echo ""

# Desinstalar External DNS
echo "🗑️  Desinstalando External DNS..."
helm uninstall external-dns -n external-dns 2>/dev/null || echo "   ℹ️  External DNS não encontrado"
echo ""

# Aguardar ALBs serem limpos
echo "⏳ Aguardando 30 segundos para ALBs serem limpos..."
sleep 30
echo "   ✅ Continuando..."
echo ""

# Deletar Services
echo "🗑️  Deletando LoadBalancer Services..."
kubectl delete svc --all --all-namespaces 2>/dev/null || echo "   ℹ️  Nenhum Service encontrado"
echo ""

# Aguardar IPs
echo "⏳ Aguardando 30 segundos para Elastic IPs serem liberados..."
sleep 30
echo "   ✅ Continuando..."
echo ""

# Desinstalar Load Balancer Controller
echo "🗑️  Desinstalando AWS Load Balancer Controller..."
helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || echo "   ℹ️  Não encontrado"
echo ""

# Aguardar final
echo "⏳ Aguardando 20 segundos para limpeza final..."
sleep 20
echo "   ✅ Pré-limpeza concluída!"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "FASE 2️⃣ : DESTROYING CLUSTER"
echo "════════════════════════════════════════════════════════════"
echo ""

cd "$BASE_DIR/cluster"
echo "📁 Diretório: $(pwd)"
echo ""

terraform init -upgrade > /dev/null 2>&1 || true
echo "🔄 Executando: terraform destroy -auto-approve"
echo ""

if terraform destroy -auto-approve; then
    echo ""
    echo "✅ Cluster destruído com sucesso!"
else
    echo ""
    echo "❌ Erro ao destruir cluster"
    echo "   Verifique os erros acima e tente novamente"
    exit 1
fi

echo ""
echo "⏳ Aguardando 60 segundos para limpeza total de recursos..."
sleep 60
echo "   ✅ Continuando..."
echo ""

echo "════════════════════════════════════════════════════════════"
echo "FASE 3️⃣ : DESTROYING NETWORKING"
echo "════════════════════════════════════════════════════════════"
echo ""

cd "$BASE_DIR/networking"
echo "📁 Diretório: $(pwd)"
echo ""

terraform init -upgrade > /dev/null 2>&1 || true
echo "🔄 Executando: terraform destroy -auto-approve"
echo ""

if terraform destroy -auto-approve; then
    echo ""
    echo "✅ Networking destruído com sucesso!"
else
    echo ""
    echo "❌ Erro ao destruir networking"
    echo "   Verifique os erros acima e tente novamente"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ DESTRUIÇÃO COMPLETA CONCLUÍDA!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "📊 Resumo:"
echo "   ✓ Cluster EKS deletado"
echo "   ✓ Node Groups deletados"
echo "   ✓ Helm Releases desinstalados"
echo "   ✓ VPC deletada"
echo "   ✓ Subnets deletadas"
echo "   ✓ NAT Gateways deletados"
echo "   ✓ Elastic IPs liberados"
echo "   ✓ Internet Gateway deletado"
echo ""
echo "🎯 Todos os recursos foram destruídos com sucesso!"
echo ""
