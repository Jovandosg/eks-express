#!/bin/bash

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Configurar Perfil AWS para Terraform                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Perfis válidos (já testados)
PROFILE="devops-nuvem"

echo "Configurando perfil: $PROFILE"
echo ""

# Exportar variável de ambiente
export AWS_PROFILE=$PROFILE

# Verificar se funciona
echo "🔍 Testando autenticação..."
if aws sts get-caller-identity --profile $PROFILE > /dev/null 2>&1; then
    echo "✅ Autenticação bem-sucedida!"
    echo ""
    echo "📊 Dados da conta:"
    aws sts get-caller-identity --profile $PROFILE
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "✅ PRONTO PARA USAR!"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "Agora você pode executar:"
    echo ""
    echo "  cd /home/kali/kenerry/NSSE-IAC/cluster"
    echo "  ./force-cleanup.sh"
    echo "  terraform destroy -auto-approve"
    echo ""
    
    # Adicionar ao ~/.bashrc para persistir
    if ! grep -q "export AWS_PROFILE=$PROFILE" ~/.bashrc; then
        echo "Salvando configuração em ~/.bashrc..."
        echo "export AWS_PROFILE=$PROFILE" >> ~/.bashrc
        echo "✅ AWS_PROFILE será carregado automaticamente no próximo terminal"
    fi
else
    echo "❌ Erro na autenticação!"
    echo ""
    echo "Tente outro perfil:"
    echo "  export AWS_PROFILE=aula"
fi
