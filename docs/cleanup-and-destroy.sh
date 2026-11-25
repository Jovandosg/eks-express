#!/bin/bash

set -e

echo "════════════════════════════════════════════════════════"
echo "🧹 LIMPEZA PRÉ-DESTROY - EKS EXPRESS CLUSTER"
echo "════════════════════════════════════════════════════════"
echo ""

# 1. Deletar todos os Ingress
echo "1️⃣  Deletando Ingress resources..."
if kubectl delete ingress --all --all-namespaces 2>/dev/null; then
    echo "   ✅ Ingress deletados"
else
    echo "   ℹ️  Nenhum Ingress encontrado"
fi
echo ""

# 2. Deletar External DNS Release
echo "2️⃣  Desinstalando Helm Release: external-dns..."
if helm uninstall external-dns -n external-dns 2>/dev/null; then
    echo "   ✅ External DNS desinstalado"
else
    echo "   ℹ️  External DNS não encontrado"
fi
echo ""

# 3. Aguardar limpeza de ALBs
echo "3️⃣  Aguardando limpeza de Application Load Balancers..."
echo "   ⏳ Esperando 30 segundos..."
sleep 30
echo "   ✅ Aguardo concluído"
echo ""

# 4. Deletar todos os LoadBalancer Services
echo "4️⃣  Deletando LoadBalancer Services..."
if kubectl delete svc --all --all-namespaces 2>/dev/null; then
    echo "   ✅ LoadBalancer Services deletados"
else
    echo "   ℹ️  Nenhum LoadBalancer Service encontrado"
fi
echo ""

# 5. Aguardar limpeza de Elastic IPs
echo "5️⃣  Aguardando liberação de Elastic IPs..."
echo "   ⏳ Esperando 30 segundos..."
sleep 30
echo "   ✅ Aguardo concluído"
echo ""

# 6. Deletar LoadBalancer Controller Release
echo "6️⃣  Desinstalando Helm Release: aws-load-balancer-controller..."
if helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null; then
    echo "   ✅ AWS Load Balancer Controller desinstalado"
else
    echo "   ℹ️  AWS Load Balancer Controller não encontrado"
fi
echo ""

# 7. Aguardar final
echo "7️⃣  Último aguardo para limpeza total..."
echo "   ⏳ Esperando 20 segundos..."
sleep 20
echo "   ✅ Aguardo concluído"
echo ""

echo "════════════════════════════════════════════════════════"
echo "✅ LIMPEZA CONCLUÍDA COM SUCESSO!"
echo "════════════════════════════════════════════════════════"
echo ""
echo "🚀 Agora você pode executar:"
echo "   cd /home/kali/kenerry/NSSE-IAC/cluster"
echo "   terraform destroy -auto-approve"
echo ""
