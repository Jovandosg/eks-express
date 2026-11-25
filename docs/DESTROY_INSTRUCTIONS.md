# 🧹 Instruções para Corrigir Erro ao Fazer `terraform destroy`

## ❌ Problema

Ao executar `terraform destroy`, você recebe erros de dependência:
```
Error: deleting EC2 Internet Gateway
Error: The subnet has dependencies and cannot be deleted
Error: Network has some mapped public address(es)
```

## 🔍 Causa

O AWS Load Balancer Controller cria automaticamente:
- **Elastic IPs** (endereços públicos)
- **Network Interfaces** nas subnets
- **Security Groups**

Esses recursos precisam ser limpos **antes** de deletar a infraestrutura de rede.

## ✅ Solução (4 Passos)

### Passo 1: Deletar todos os Ingress resources
```bash
kubectl delete ingress --all --all-namespaces
```

### Passo 2: Aguardar limpeza dos ALBs (30 segundos)
Os ALBs criados pelo Ingress serão deletados automaticamente, liberando as Elastic IPs.
```bash
sleep 30
```

### Passo 3: Deletar todos os LoadBalancer Services
```bash
kubectl delete svc --all --all-namespaces
```

### Passo 4: Aguardar liberação de IPs (20 segundos)
```bash
sleep 20
```

## 🚀 Executar Destroy Limpo

Agora execute o destroy com segurança:
```bash
terraform destroy -auto-approve
```

## 📋 Versão Automatizada

Ou use o script de limpeza automática:
```bash
chmod +x /tmp/cleanup-destroy.sh
/tmp/cleanup-destroy.sh
```

## 💡 Dica: Usar Script Completo

```bash
#!/bin/bash
set -e

echo "🧹 Limpando recursos do Kubernetes..."
kubectl delete ingress --all --all-namespaces 2>/dev/null || true
echo "   ✅ Ingress deletados"

sleep 30
echo "   ⏳ Aguardando limpeza de ALBs..."

kubectl delete svc --all --all-namespaces 2>/dev/null || true
echo "   ✅ Services deletados"

sleep 20
echo "   ⏳ Aguardando limpeza de Elastic IPs..."

echo "✅ Limpeza concluída!"
echo ""
echo "🚀 Agora execute:"
echo "   terraform destroy -auto-approve"
```

## ⚠️ Importante

- **Não pule o tempo de espera!** Os recursos na AWS levam tempo para serem limpos
- Se ainda tiver erros, aumente o tempo de espera para 60-90 segundos
- Se o erro persistir, verifique manualmente no AWS Console quais recursos ainda existem

## 🔗 Referências

- AWS Load Balancer Controller: Cria ALBs automaticamente via Ingress
- External DNS: Cria registros Route 53 automaticamente
- Helm releases precisam ser desinstalados antes de destruir dependências
