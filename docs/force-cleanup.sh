#!/bin/bash

set -e

echo "════════════════════════════════════════════════════════════"
echo "🔨 LIMPEZA FORÇADA - Removendo TODAS as dependências"
echo "════════════════════════════════════════════════════════════"
echo ""

# 1. Deletar todos os recursos do Kubernetes
echo "1️⃣  Deletando TODOS os recursos Kubernetes..."
kubectl delete all --all --all-namespaces 2>/dev/null || echo "   ℹ️  Nenhum recurso encontrado"
kubectl delete ingress --all --all-namespaces 2>/dev/null || echo "   ℹ️  Nenhum Ingress"
kubectl delete services --all --all-namespaces 2>/dev/null || echo "   ℹ️  Nenhum Service"
kubectl delete pvc --all --all-namespaces 2>/dev/null || echo "   ℹ️  Nenhum PVC"
echo "   ✅ Recursos K8s deletados"
echo ""

# 2. Desinstalar TODOS os Helm releases
echo "2️⃣  Desinstalando TODOS os Helm releases..."
helm list -A --short 2>/dev/null | while read release; do
    echo "   🗑️  Deletando: $release"
    helm uninstall $release --namespace $(helm list -A | grep $release | awk '{print $1}') 2>/dev/null || true
done
echo "   ✅ Helm releases desinstalados"
echo ""

# 3. Aguardar limpeza
echo "3️⃣  Aguardando limpeza de recursos (45 segundos)..."
sleep 45
echo "   ✅ Continuando..."
echo ""

# 4. Deletar namespaces customizados (deixa padrões)
echo "4️⃣  Deletando namespaces customizados..."
kubectl delete namespace external-dns 2>/dev/null || echo "   ℹ️  external-dns não encontrado"
kubectl delete namespace prometheus 2>/dev/null || echo "   ℹ️  prometheus não encontrado"
kubectl delete namespace istio-system 2>/dev/null || echo "   ℹ️  istio-system não encontrado"
echo "   ✅ Namespaces customizados deletados"
echo ""

# 5. Aguardar final
echo "5️⃣  Aguardando finalização (30 segundos)..."
sleep 30
echo "   ✅ Pronto para destroy!"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "✅ LIMPEZA FORÇADA CONCLUÍDA!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "🚀 Agora execute:"
echo ""
echo "   # Para cluster:"
echo "   cd /home/kali/kenerry/NSSE-IAC/cluster"
echo "   terraform destroy -auto-approve"
echo ""
echo "   # Para networking:"
echo "   cd /home/kali/kenerry/NSSE-IAC/networking"
echo "   terraform destroy -auto-approve"
echo ""
