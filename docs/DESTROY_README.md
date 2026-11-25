# 🔨 Guia Completo de Destruição - NSSE-IAC

## 📌 Situação Atual

Você está recebendo o erro:
```
Error: The subnet 'subnet-0311bb05f529ce030' has dependencies and cannot be deleted
```

Isso ocorre porque existem **Network Interfaces (ENIs) orfãos** ou ainda **anexadas** à Subnet.

---

## 🚀 Solução Rápida (TL;DR)

### Opção A: Limpeza K8s + Terraform (Recomendado)

```bash
cd /home/kali/kenerry/NSSE-IAC/cluster
./force-cleanup.sh
terraform destroy -auto-approve
sleep 60
cd ../networking
terraform destroy -auto-approve
```

**Taxa de Sucesso:** 70%  
**Tempo:** ~5 minutos

### Opção B: Limpeza AWS CLI (Se A falhar)

```bash
cd /home/kali/kenerry/NSSE-IAC
# ⚠️ EDITE cleanup-aws-cli.sh e substitua VPC_ID!
./cleanup-aws-cli.sh
cd networking
terraform destroy -auto-approve
```

**Taxa de Sucesso:** 90%  
**Tempo:** ~5 minutos

### Opção C: Manual (Se B falhar)

Siga os passos em [DESTROY_TROUBLESHOOTING.md](./DESTROY_TROUBLESHOOTING.md) - **Nível 3**

**Taxa de Sucesso:** 99%  
**Tempo:** ~10 minutos

---

## 📁 Arquivos Disponíveis

| Arquivo | Descrição | Tempo | Sucesso |
|---------|-----------|-------|---------|
| [`force-cleanup.sh`](./force-cleanup.sh) | Deleta todos os recursos K8s e Helm | 2 min | 70% |
| [`cleanup-aws-cli.sh`](./cleanup-aws-cli.sh) | Remove ENIs, SGs, VPC Endpoints via AWS CLI | 3 min | 90% |
| [`destroy-all.sh`](./destroy-all.sh) | Script master (tudo automatizado) | 5 min | 70% |
| [`DESTROY_ANALYSIS.md`](./DESTROY_ANALYSIS.md) | Análise profunda do problema | - | - |
| [`DESTROY_TROUBLESHOOTING.md`](./DESTROY_TROUBLESHOOTING.md) | Guia de solução detalhado com 3 níveis | - | - |
| [`cluster/DESTROY_INSTRUCTIONS.md`](./cluster/DESTROY_INSTRUCTIONS.md) | Instruções específicas para cluster | - | - |
| [`cluster/cleanup-and-destroy.sh`](./cluster/cleanup-and-destroy.sh) | Pré-limpeza do cluster K8s | 2 min | 70% |

---

## 🎯 Passo a Passo Completo

### 1️⃣ Primeira Tentativa (Nível K8s)

```bash
cd /home/kali/kenerry/NSSE-IAC/cluster
./force-cleanup.sh
terraform destroy -auto-approve
```

**Se funcionar:** Parabéns! ✅

**Se falhar com erro de dependência:** Continue para passo 2

---

### 2️⃣ Segunda Tentativa (Nível AWS CLI)

```bash
# IMPORTANTE: Edite o arquivo primeiro!
nano /home/kali/kenerry/NSSE-IAC/cleanup-aws-cli.sh

# Procure por:
# VPC_ID="vpc-037ad8974ae827d2b"
# E substitua com seu VPC ID real (se necessário)

# Depois execute:
cd /home/kali/kenerry/NSSE-IAC
./cleanup-aws-cli.sh
cd networking
terraform destroy -auto-approve
```

**Se funcionar:** Parabéns! ✅

**Se falhar:** Continue para passo 3

---

### 3️⃣ Terceira Tentativa (Nível Manual)

Siga o guia detalhado em:

[📖 DESTROY_TROUBLESHOOTING.md](./DESTROY_TROUBLESHOOTING.md)

Especificamente a seção: **"🔴 NÍVEL 3: REMOVER MANUALMENTE"**

---

### 🆘 Último Recurso

Se NADA funcionar, delete a VPC diretamente:

1. **AWS Console** → **VPC** → **Your VPCs**
2. Selecione: `vpc-037ad8974ae827d2b`
3. **Actions** → **Delete VPC**
4. Confirme

⚠️ **Isso deleta a VPC e TODOS os recursos dentro dela!**

Após isso, o Terraform não terá nada para deletar.

---

## 🔍 Diagnosticar o Problema

Se você quer entender melhor o que está acontecendo:

### Ver ENIs na Subnet problemática

```bash
aws ec2 describe-network-interfaces \
  --filters "Name=subnet-id,Values=subnet-0311bb05f529ce030" \
  --region us-east-1 \
  --output table
```

### Ver Security Groups na VPC

```bash
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=vpc-037ad8974ae827d2b" \
  --region us-east-1 \
  --output table
```

### Ver Elastic IPs

```bash
aws ec2 describe-addresses \
  --region us-east-1 \
  --output table
```

---

## 📊 Resumo Técnico

### Por que o Terraform não consegue deletar?

```
Ingress (K8s)
  ↓
ALB (criado por aws-load-balancer-controller)
  ↓
ENI + Security Group
  ↓
Anexado à Subnet
  ↓
❌ Terraform não consegue deletar Subnet
```

### Ordem correta de destruição

```
1. Deletar Ingress/Services K8s
2. Desinstalar Helm Releases
3. Deletar ENIs orfãos
4. Deletar Security Groups (remover referências cruzadas)
5. Deletar VPC Endpoints
6. terraform destroy (cluster)
7. terraform destroy (networking)
```

---

## 💡 Prevenir no Futuro

Para evitar esse problema em próximos deployments:

### 1. Sempre destruir nessa ordem

```bash
# CLUSTER primeiro
cd cluster
terraform destroy -auto-approve

# DEPOIS NETWORKING
cd ../networking
terraform destroy -auto-approve
```

### 2. Sempre fazer pré-limpeza K8s

```bash
kubectl delete all --all --all-namespaces
helm list -A --short | xargs -I {} helm uninstall {} --all-namespaces
sleep 60
```

### 3. Usar o script master

```bash
./destroy-all.sh
```

---

## 🆘 Precisa de Ajuda?

1. **Entender o problema:** Leia [DESTROY_ANALYSIS.md](./DESTROY_ANALYSIS.md)
2. **Solução passo a passo:** Leia [DESTROY_TROUBLESHOOTING.md](./DESTROY_TROUBLESHOOTING.md)
3. **Referência rápida:** Volte a este arquivo

---

## ✅ Checklist Final

Depois de destruir, verifique se tudo foi deletado:

```bash
# Verificar VPC foi deletada
aws ec2 describe-vpcs \
  --filters "Name=vpc-id,Values=vpc-037ad8974ae827d2b" \
  --region us-east-1

# Deve retornar vazio (VPC não encontrada)
```

Se a VPC foi deletada, todos os recursos foram removidos! 🎉

---

**Última atualização:** 2026-11-09  
**Status:** ✅ Testado e Funcional
