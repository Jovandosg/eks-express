# 🔍 Análise: Por que `terraform destroy` não destrói todos os recursos

## 📊 Estrutura do Projeto

```
NSSE-IAC/
├── networking/          ← Gerencia VPC, Subnets, IGW, NAT Gateways
│   ├── main.tf          (Backend S3: nsse-state-files/networking)
│   ├── vpc.tf
│   ├── vpc.nat-gateways.tf
│   ├── ec2.eips.tf
│   └── ...
│
└── cluster/             ← Gerencia EKS Cluster, Helm Charts, etc
    ├── main.tf
    ├── eks.cluster.tf
    ├── eks.cluster.node-group.tf
    └── ...
```

## 🔑 O PROBLEMA PRINCIPAL

### **São 2 módulos Terraform SEPARADOS com estados SEPARADOS!**

```
networking/terraform.tfvars    → Backend S3: networking/terraform.tfstate
cluster/terraform.tfvars       → Backend S3: cluster/terraform.tfstate
```

Quando você executa `terraform destroy` na pasta `/cluster`, **apenas os recursos do cluster são destruídos**, não os da VPC/Networking.

---

## 📋 O que cada módulo gerencia

### 🔴 **NETWORKING** (NÃO é destruído por `terraform destroy` na pasta cluster)

```hcl
✓ AWS VPC (aws_vpc.this)
✓ Internet Gateway (aws_internet_gateway.this)
✓ NAT Gateways (aws_nat_gateway.this)
✓ Elastic IPs (aws_eip.this) ← AQUI ESTÁ O PROBLEMA!
✓ Public Subnets (aws_subnet.public)
✓ Private Subnets (aws_subnet.private)
✓ Route Tables (public + private)
```

### 🟢 **CLUSTER** (É destruído normalmente)

```hcl
✓ EKS Cluster (aws_eks_cluster.this)
✓ EKS Node Group (aws_eks_node_group.this)
✓ IAM Roles/Policies
✓ KMS Keys
✓ Helm Releases (external-dns, load-balancer-controller)
✓ ACM Certificate
✓ Route 53 Records
```

---

## ❌ Por que ainda temos erros de dependência?

### **O Fluxo de Destruição:**

```
terraform destroy na pasta /cluster
    ↓
Tenta deletar: EKS, Node Groups, Helm Releases
    ↓
Helm Release (load-balancer-controller) é desinstalado
    ↓
ALB criado pelo Ingress é deletado
    ↓
MAS: Elastic IPs ainda estão ANEXADAS ao ENI do ALB
    ↓
Terraform tenta deletar a Subnet/IGW
    ↓
AWS recusa: "Subnet has dependencies"
         ou "IGW has mapped public addresses"
```

### **Por quê as Elastic IPs não são limpas?**

As Elastic IPs foram criadas pela configuração **`networking/`**, não pelo **`cluster/`**!

```
networking/ec2.eips.tf:
  resource "aws_eip" "this" {  ← Criado por networking/
    domain = "vpc"
  }

networking/vpc.nat-gateways.tf:
  allocation_id = aws_eip.this[count.index].id  ← Usada por NAT Gateway
```

O cluster referencia a VPC e Subnets via **data source**:

```hcl
# cluster/data.networking.tf
data "terraform_remote_state" "networking" {  ← LÊ, não gerencia!
  backend = "s3"
  config = {
    key = "networking/terraform.tfstate"
  }
}
```

---

## 🛑 Bloqueios de Destruição

### **Em `cluster/eks.cluster.tf`:**

```hcl
resource "aws_eks_cluster" "this" {
  lifecycle {
    # Prevents accidental destruction of the EKS cluster
    prevent_destroy = false  ← Pode ser destruído
  }
}
```

### **Em `cluster/eks.cluster.node-group.tf`:**

```hcl
resource "aws_eks_node_group" "this" {
  lifecycle {
    prevent_destroy = false  ← Pode ser destruído
  }
}
```

✅ Esses blocos têm `prevent_destroy = false`, então destruição é permitida.

---

## 🔧 Solução Correta

### **Opção 1: Destroy Correto (Recomendado)**

```bash
# Passo 1: Limpar recursos Kubernetes
cd /home/kali/kenerry/NSSE-IAC/cluster
./cleanup-and-destroy.sh

# Passo 2: Destruir cluster
terraform destroy -auto-approve

# Passo 3: Destruir networking (SEPARADAMENTE!)
cd /home/kali/kenerry/NSSE-IAC/networking
terraform destroy -auto-approve
```

### **Opção 2: Script Completo Automatizado**

```bash
#!/bin/bash

echo "🧹 Destruindo Cluster EKS..."
cd /home/kali/kenerry/NSSE-IAC/cluster
./cleanup-and-destroy.sh
terraform destroy -auto-approve

echo "⏳ Aguardando 60 segundos..."
sleep 60

echo "🧹 Destruindo Networking..."
cd /home/kali/kenerry/NSSE-IAC/networking
terraform destroy -auto-approve

echo "✅ Destruição completa!"
```

### **Opção 3: Se quiser destruir tudo simultaneamente**

Você precisaria refatorar para um único módulo Terraform (não recomendado).

---

## 📊 Cronograma de Destruição

```
Cluster Destroy
├── 1. Deletar Ingress/Services
├── 2. Desinstalar Helm Releases
├── 3. Deletar EKS Node Group
├── 4. Deletar EKS Cluster
├── 5. Deletar Security Groups
└── ✅ COMPLETO (mas VPC ainda existe!)

Networking Destroy
├── 1. Deletar Route Table Associations
├── 2. Deletar Route Tables
├── 3. Deletar Subnets
├── 4. Deletar NAT Gateways
├── 5. Liberar Elastic IPs
├── 6. Deletar Internet Gateway
└── ✅ COMPLETO

Total: ~2-3 minutos
```

---

## ⚠️ Erros Comuns ao Tentar Destroy Único

### ❌ Erro: "Subnet has dependencies"

**Causa:** Recursos do cluster ainda existem

**Solução:** Sempre execute `cluster destroy` antes de `networking destroy`

### ❌ Erro: "IGW has mapped public address"

**Causa:** Elastic IPs ainda estão anexadas

**Solução:** Aguarde pelo menos 60 segundos após deletar cluster

### ❌ Erro: "Helm release still has active resources"

**Causa:** Ingress ainda existe

**Solução:** Execute `kubectl delete ingress --all` antes

---

## 🎯 Checklist de Destruição Segura

```
✅ Executar ./cleanup-and-destroy.sh
✅ Executar terraform destroy -auto-approve (cluster/)
✅ Aguardar 60 segundos
✅ Verificar no AWS Console se recursos foram deletados
✅ Executar terraform destroy -auto-approve (networking/)
✅ Verificar VPC está deletada
```

---

## 📝 Resumo

| Aspecto | Detalhes |
|--------|----------|
| **Número de módulos** | 2 (networking + cluster) |
| **Estados separados?** | SIM (S3 remote state) |
| **Destroy único é possível?** | NÃO (dependências de ordem) |
| **Ordem correta** | Cluster → Networking |
| **Tempo total** | 2-3 minutos |
| **Recursos que ficam?** | Nenhum (se tudo correr bem) |

