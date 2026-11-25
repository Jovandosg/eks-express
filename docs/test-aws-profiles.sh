#!/bin/bash

echo "════════════════════════════════════════════════════════════"
echo "🧪 Testando Perfis AWS"
echo "════════════════════════════════════════════════════════════"
echo ""

# Perfis para testar
PROFILES=("default" "aula" "bia" "devops-nuvem")

VALID_PROFILES=()

for profile in "${PROFILES[@]}"; do
    echo "🔍 Testando perfil: $profile"
    
    if aws sts get-caller-identity --profile "$profile" 2>/dev/null; then
        echo "   ✅ VÁLIDO"
        VALID_PROFILES+=("$profile")
    else
        echo "   ❌ INVÁLIDO (credenciais expiradas ou incorretas)"
    fi
    echo ""
done

echo "════════════════════════════════════════════════════════════"
echo "📊 RESULTADO"
echo "════════════════════════════════════════════════════════════"
echo ""

if [ ${#VALID_PROFILES[@]} -eq 0 ]; then
    echo "❌ NENHUM PERFIL VÁLIDO!"
    echo ""
    echo "🔧 Para resolver:"
    echo ""
    echo "Opção 1: Usar SSO"
    echo "  aws sso login --profile default"
    echo ""
    echo "Opção 2: Regenerar Access Key"
    echo "  1. Abra: https://console.aws.amazon.com/"
    echo "  2. Vá para: IAM → Users → Seu usuário"
    echo "  3. Create Access Key"
    echo "  4. Execute: aws configure --profile default"
    echo ""
else
    echo "✅ PERFIS VÁLIDOS:"
    for profile in "${VALID_PROFILES[@]}"; do
        echo "   • $profile"
    done
    echo ""
    echo "🚀 Use com Terraform:"
    echo ""
    echo "   export AWS_PROFILE=${VALID_PROFILES[0]}"
    echo "   terraform destroy -auto-approve"
    echo ""
fi

echo "════════════════════════════════════════════════════════════"
