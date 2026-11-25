# 🔨 Guia de Solução: Destroy Contínuo Falhando

## Helm e certificado ACM em uso no cluster

Antes do destroy do cluster, remova somente o Ingress da aplicacao, mantendo
os controllers, nodes e acessos administrativos ativos:

```bash
kubectl delete ingress eks-express-ingress -n default
```

Aguarde o AWS Load Balancer Controller excluir o ALB e liberar o certificado
antes de executar o destroy. O Ingress aplicado por kubectl nao pertence ao
estado Terraform; o destroy nao garante sua limpeza automatica.

Se o destroy ja removeu os acessos ou nodes, nao reaplique todo o projeto:
restaure um acesso administrativo temporario e inspecione o ALB associado ao
certificado com `aws acm describe-certificate`. Remova apenas os recursos
confirmados desta aplicacao antes de retomar o destroy.

A zona Route53 existente e os registros de outros sites nao devem ser excluidos.
Registros A/AAAA/TXT do ExternalDNS podem permanecer orfaos; o CNAME de validacao
ACM gerenciado pelo Terraform sera removido no destroy.

## ❌ Erro Recebido

```
Error: deleting EC2 Subnet (subnet-0311bb05f529ce030): 
The subnet 'subnet-0311bb05f529ce030' has dependencies and cannot be deleted
```

## 🔍 Diagnosticar

A Subnet tem dependências que o Terraform não está deletando automaticamente.

Possíveis causas:
- ❌ Network Interfaces (ENI) ainda anexadas
- ❌ VPC Endpoints não deletados
- ❌ Security Groups com regras de referência cruzada
- ❌ DHCP Options Sets
- ❌ Elastic IPs ainda reservadas

## ✅ Soluções em Ordem de Complexidade

### 🔵 Nível 1: Limpeza K8s Completa

```bash
cd /home/kali/kenerry/NSSE-IAC/cluster
./force-cleanup.sh
```

**O que faz:**
- Deleta TODOS os recursos do Kubernetes
- Deleta TODOS os Helm releases
- Aguarda 45-75 segundos para propagação

**Depois:**
```bash
terraform destroy -auto-approve
```

---

### 🟠 Nível 2: Limpeza Manual via AWS CLI

```bash
cd /home/kali/kenerry/NSSE-IAC
./cleanup-aws-cli.sh
```

**O que faz:**
- Remove Network Interfaces orfãos
- Remove Security Groups não usados
- Remove VPC Endpoints
- Aguarda 30 segundos

**Depois:**
```bash
cd networking
terraform destroy -auto-approve
```

---

### 🔴 Nível 3: Remover Manualmente (Nuclear)

Se os scripts acima falharem, você precisa fazer isto **no console AWS**:

#### 3.1 Verificar Network Interfaces

1. Abra: https://console.aws.amazon.com/ec2/
2. Vá para: **Network Interfaces**
3. Filtre por VPC: `vpc-037ad8974ae827d2b`
4. Para cada ENI em status `available`:
   - Clique com botão direito
   - **Detach** (se anexada)
   - **Delete**

#### 3.2 Verificar Security Groups

1. Vá para: **Security Groups**
2. Filtre por VPC: `vpc-037ad8974ae827d2b`
3. Para cada SG que NÃO é "default":
   - Clique
   - Vá para "Inbound Rules"
   - Remova regras que referenciam outros SGs
   - Vá para "Outbound Rules"
   - Remova regras que referenciam outros SGs
   - Delete o SG

#### 3.3 Verificar VPC Endpoints

1. Vá para: **Endpoints**
2. Filtre por VPC: `vpc-037ad8974ae827d2b`
3. Para cada Endpoint:
   - Selecione
   - **Actions** → **Delete**

#### 3.4 Verificar Elastic IPs

1. Vá para: **Elastic IPs**
2. Para cada EIP que NÃO está associado:
   - Selecione
   - **Release address**

#### 3.5 Depois de limpar manualmente

```bash
cd /home/kali/kenerry/NSSE-IAC/networking
terraform destroy -auto-approve
```

---

## 🚨 Problemas Específicos

### "The subnet has dependencies"

**Significa:** Ainda há Network Interfaces naquela Subnet

**Solução:**
```bash
# Encontre ENIs na Subnet
aws ec2 describe-network-interfaces \
  --filters "Name=subnet-id,Values=subnet-0311bb05f529ce030" \
  --region us-east-1

# Delete cada ENI
aws ec2 delete-network-interface \
  --region us-east-1 \
  --network-interface-id <ENI_ID>
```

### "IGW has mapped public addresses"

**Significa:** Ainda há Elastic IPs associadas

**Solução:**
```bash
# Liste EIPs
aws ec2 describe-addresses --region us-east-1

# Dissocie EIPs
aws ec2 disassociate-address \
  --region us-east-1 \
  --association-id <ASSOC_ID>

# Libere EIPs
aws ec2 release-address \
  --region us-east-1 \
  --allocation-id <ALLOC_ID>
```

### "Could not deliver TypeNotFound errors"

**Significa:** Há referências cruzadas entre Security Groups

**Solução:**
1. Remova regras de ingress/egress que referenciam outros SGs
2. Aguarde 10 segundos
3. Delete os SGs

---

## 📋 Checklist de Destruição Completa

```
PASSO 1: CLUSTER
├─ ./force-cleanup.sh
├─ terraform destroy -auto-approve
└─ Aguarde 60 segundos

PASSO 2: NETWORKING
├─ ./cleanup-aws-cli.sh
├─ terraform destroy -auto-approve
└─ Se falhar → vá para Nível 3

PASSO 3: VERIFICAR
├─ Console AWS
├─ Verifique que VPC foi deletada
├─ Verifique que Subnets foram deletadas
└─ Verifique que Security Groups foram deletados
```

---

## 💡 Dica Profissional

Se quiser **nunca mais ter esse problema**, estruture seus módulos assim:

```
main/
├── networking/
│   └── (sempre apply/destroy primeiro)
└── cluster/
    └── (apply/destroy por último)
```

E adicione em `networking/main.tf`:

```hcl
resource "null_resource" "destroy_order_dependency" {
  triggers = {
    cluster_ready = data.terraform_remote_state.cluster.outputs.cluster_arn
  }
}
```

Isso força a ordem correta.

---

## 🆘 Se Nada Funcionar

**Último recurso:** Delete a VPC manualmente no console AWS

1. AWS Console → VPC → VPCs
2. Selecione: `vpc-037ad8974ae827d2b`
3. **Actions** → **Delete VPC**
4. AWS irá deletar TUDO automaticamente

⚠️ Isso remove a VPC e TODOS os recursos dentro dela!
