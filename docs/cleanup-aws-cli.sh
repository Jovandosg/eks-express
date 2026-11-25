#!/bin/bash

set -e

echo "════════════════════════════════════════════════════════════"
echo "⚠️  LIMPEZA MANUAL VIA AWS CLI - Nível NUCLEAR"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Este script irá remover MANUALMENTE via AWS CLI:"
echo "  ❌ Network Interfaces orfãos"
echo "  ❌ Security Groups não usados"
echo "  ❌ Elastic Network Adapters"
echo "  ❌ Endpoints VPC"
echo ""

REGION="us-east-1"
VPC_ID="vpc-037ad8974ae827d2b"  # Substitua com seu VPC ID

echo "Usando:"
echo "  Região: $REGION"
echo "  VPC ID: $VPC_ID"
echo ""

read -p "⚠️  Continuar? (s/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Operação cancelada"
    exit 1
fi

echo ""
echo "1️⃣  Removendo Network Interfaces não primárias..."
aws ec2 describe-network-interfaces \
    --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'NetworkInterfaces[?!Attachment.DeviceIndex==`0`].NetworkInterfaceId' \
    --output text | while read eni; do
    if [ -n "$eni" ]; then
        echo "   🗑️  Deletando ENI: $eni"
        aws ec2 delete-network-interface --region $REGION --network-interface-id $eni 2>/dev/null || echo "      ⚠️  Erro (pode estar em uso)"
    fi
done
echo "   ✅ Concluído"
echo ""

echo "2️⃣  Removendo Network Interfaces em estado 'available'..."
aws ec2 describe-network-interfaces \
    --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=status,Values=available" \
    --query 'NetworkInterfaces[].NetworkInterfaceId' \
    --output text | while read eni; do
    if [ -n "$eni" ]; then
        echo "   🗑️  Deletando ENI: $eni"
        aws ec2 delete-network-interface --region $REGION --network-interface-id $eni 2>/dev/null || echo "      ⚠️  Erro (pode estar em uso)"
    fi
done
echo "   ✅ Concluído"
echo ""

echo "3️⃣  Removendo VPC Endpoints..."
aws ec2 describe-vpc-endpoints \
    --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'VpcEndpoints[].VpcEndpointId' \
    --output text | while read endpoint; do
    if [ -n "$endpoint" ]; then
        echo "   🗑️  Deletando Endpoint: $endpoint"
        aws ec2 delete-vpc-endpoints --region $REGION --vpc-endpoint-ids $endpoint 2>/dev/null || echo "      ⚠️  Erro"
    fi
done
echo "   ✅ Concluído"
echo ""

echo "4️⃣  Removendo Security Groups (exceto default)..."
aws ec2 describe-security-groups \
    --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
    --output text | while read sg; do
    if [ -n "$sg" ]; then
        echo "   🗑️  Deletando Security Group: $sg"
        aws ec2 delete-security-group --region $REGION --group-id $sg 2>/dev/null || echo "      ⚠️  Erro (pode ter dependências)"
    fi
done
echo "   ✅ Concluído"
echo ""

echo "5️⃣  Aguardando 30 segundos para propagação de mudanças..."
sleep 30
echo "   ✅ Pronto!"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "✅ LIMPEZA MANUAL CONCLUÍDA!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "🚀 Agora execute:"
echo "   cd /home/kali/kenerry/NSSE-IAC/networking"
echo "   terraform destroy -auto-approve"
echo ""
