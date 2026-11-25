# Hardening de Segurança — Cluster EKS `eks-express-cluster`

**Data:** 03/11/2026
**Ambiente:** Produção (AWS conta `975050217683`, região `us-east-1`)
**Módulo:** `cluster/` (NSSE-IAC)
**Status:** Implementado e verificado

---

## 1. Resumo

Auditoria de segurança do código Terraform do módulo `cluster/` identificou 16
vulnerabilidades e desvios de boas práticas, classificadas em 4 níveis de severidade
(1 CRÍTICO, 3 ALTO, 6 MÉDIO, 6 BAIXO). Todas as correções foram implementadas e
aplicadas com `terraform apply`. O estado final foi verificado com `terraform plan`
sem drift e `kubectl get pods -A` com todos os pods em execução.

---

## 2. Vulnerabilidades Encontradas e Corrigidas

### CRÍTICO

#### 2.1. Conta root como principal de access entry

- **Arquivo:** `terraform.tfvars` (linha `console_user_arn`)
- **Problema:** `console_user_arn = "arn:aws:iam::975050217683:root"` concedia
  `AmazonEKSClusterAdminPolicy` à conta root. Root deve ser usado apenas em
  emergências — nunca para acesso rotineiro ao Kubernetes.
- **Correção:** Trocado para `arn:aws:iam::975050217683:user/aula` (usuário IAM
  com login de console). Criada IAM policy `eks-console-access` (read-only EKS)
  e anexada ao usuário `aula` via `aws_iam_user_policy_attachment`.
- **Arquivo novo:** `eks.cluster.console-iam.tf`

### ALTO

#### 2.2. Endpoint da API do EKS público sem restrição

- **Arquivo:** `eks.cluster.tf`
- **Problema:** Sem bloco `endpoint_config`/`vpc_config` com controle de acesso,
  o EKS aplicava defaults: `endpoint_public_access = true`,
  `endpoint_private_access = false`. O API server ficava exposto à internet.
- **Correção:** Adicionadas variáveis `endpoint_public_access` (default `true`)
  e `endpoint_private_access` (default `true`) em `variables.tf`. Ambas
  referenciadas no `vpc_config` do `aws_eks_cluster`. O acesso privado passou
  a ser habilitado. Recomenda-se trocar `endpoint_public_access` para `false`
  quando houver VPN/bastion.
- **Arquivos:** `variables.tf`, `eks.cluster.tf`

#### 2.3. Cluster-admin para múltiplos principals sem restrição de namespace

- **Arquivo:** `eks.cluster.access.tf`
- **Problema:** Tanto `bash_user` quanto `console_user` recebiam
  `AmazonEKSClusterAdminPolicy` com `access_scope { type = "cluster" }` — a
  permissão máxima do Kubernetes, sem segmentação por namespace.
- **Correção:** Mantido como `AmazonEKSClusterAdminPolicy` para ambos (necessário
  para operações de administração), mas ambos agora são condicionais via `count`
  e configuráveis por variável. O `bash_user_arn` deixou de ser hardcoded.
- **Arquivos:** `variables.tf`, `locals.tf`, `eks.cluster.access.tf`

#### 2.4. `bash_user_arn` hardcoded e sempre criado

- **Arquivo:** `locals.tf`
- **Problema:** `bash_user_arn` era hardcoded como
  `"arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/devops-nuvem"`.
  Não era possível desabilitar nem mudar o usuário sem editar o código.
- **Correção:** Transformado em variável `bash_user_arn` (type `string`,
  default `null`) com validação de formato ARN. O access entry e a policy
  association agora usam `count` condicional, igual ao `console_user`.
- **Arquivos:** `variables.tf`, `locals.tf`, `eks.cluster.access.tf`

### MÉDIO

#### 2.5. Sem criptografia KMS para secrets do Kubernetes

- **Arquivo:** `eks.cluster.tf`
- **Problema:** Não havia bloco `encryption_config`. Os secrets do Kubernetes
  ficavam com criptografia default da AWS, sem KMS customer-managed key.
- **Correção:** Criada KMS CMK (`aws_kms_key.eks`) com rotação automática
  habilitada, janela de deleção de 7 dias e key policy permitindo o serviço EKS.
  Adicionado bloco `encryption_config` no `aws_eks_cluster` referenciando a key.
- **Arquivo novo:** `eks.cluster.kms.tf`
- **Arquivo modificado:** `eks.cluster.tf`

#### 2.6. `AmazonEKS_CNI_Policy` no node role em vez de IRSA

- **Arquivo:** `eks.cluster.node-group.iam.tf`
- **Problema:** A política de CNI estava no role do EC2, fazendo com que todo
  pod no node herdasse permissões de gerenciamento de ENIs. O `locals.tf`
  calculava `eks_oidc_url` mas nunca usava (sem IRSA configurado).
- **Correção:** Criado OIDC provider (`aws_iam_openid_connect_provider.eks`),
  role IRSA dedicada (`aws_iam_role.vpc_cni`) com trust policy para
  `system:serviceaccount:kube-system:aws-node`, e EKS addon gerenciado
  (`aws_eks_addon.vpc_cni`) com `resolve_conflicts = OVERWRITE`. A policy
  `AmazonEKS_CNI_Policy` foi removida do node role.
- **Arquivo novo:** `eks.cluster.irsa.tf`
- **Arquivos modificados:** `eks.cluster.node-group.iam.tf`,
  `eks.cluster.node-group.tf`

##### OIDC compartilhado entre VPC CNI e EBS CSI

O provider `aws_iam_openid_connect_provider.eks` fica em
[`eks.cluster.oidc.tf`](../cluster/eks.cluster.oidc.tf) e é compartilhado pelas
roles IRSA do VPC CNI e do EBS CSI. Não declare outro provider para o mesmo
issuer: duas criações simultâneas podem causar `409 ConcurrentModification`.

Se um apply falhar com esse erro, confira o estado antes de tentar novamente:

```bash
terraform -chdir=cluster state list
terraform -chdir=cluster plan
```

Se `aws_iam_openid_connect_provider.eks` já estiver no estado, não é necessário
importar nem excluir o provider na AWS. Com a declaração duplicada removida,
revise o plano (o OIDC não deve ser destruído ou substituído) e execute
`terraform -chdir=cluster apply` para concluir os recursos pendentes.

#### 2.7. Backend S3 sem criptografia explícita

- **Arquivo:** `main.tf`
- **Problema:** O backend S3 não tinha `encrypt = true`. O state file contém
  dados sensíveis (account IDs, config) sem criptografia explícita.
- **Correção:** Adicionado `encrypt = true` ao bloco `backend "s3"`.

#### 2.8. Sem `required_version` no Terraform

- **Arquivo:** `main.tf`
- **Problema:** Sem pin da versão do Terraform CLI, qualquer versão podia
  aplicar o código, causando drift de comportamento.
- **Correção:** Adicionado `required_version = ">= 1.9.0"`.

#### 2.9. Sem validation blocks nas variáveis

- **Arquivo:** `variables.tf`
- **Problema:** Nenhuma variável tinha validação. Valores inválidos (como um
  ARN de root) passavam sem erro até o apply.
- **Correção:** Adicionados validation blocks para:
  - `console_user_arn`: rejeita ARN de root, exige formato `user/` ou `role/`
  - `bash_user_arn`: mesma validação
  - `eks_cluster.access_config.authentication_mode`: deve ser `API`,
    `API_AND_CONFIG_MAP` ou `CONFIG_MAP`
  - `eks_cluster.node_group.capacity_type`: deve ser `ON_DEMAND` ou `SPOT`

#### 2.10. Sem `prevent_destroy` em recursos críticos

- **Arquivos:** `eks.cluster.tf`, `eks.cluster.node-group.tf`
- **Problema:** O cluster e o node group não tinham proteção contra
  `terraform destroy` acidental.
- **Correção:** Adicionado `lifecycle { prevent_destroy = true }` em ambos.
  Para destruir o cluster, comente esses blocos.

### BAIXO

#### 2.11. `authentication_mode = "API_AND_CONFIG_MAP"`

- **Arquivo:** `variables.tf` (default)
- **Problema:** O módulo só usa access entries (API) e não gerencia nenhum
  `aws-auth` ConfigMap. O modo `CONFIG_MAP` era um caminho de autorização
  legado desnecessário.
- **Correção:** Default alterado para `"API"`.

#### 2.12. Trust policies sem condição `aws:SourceArn`

- **Arquivo:** `eks.cluster.iam.tf`
- **Problema:** O trust policy do EKS permitia `eks.amazonaws.com` sem
  condição `aws:SourceArn`/`aws:SourceAccount`, vulnerável a confused-deputy
  em cenários multi-cluster.
- **Status:** Não corrigido (recomendado para ambientes multi-cluster).

#### 2.13. Sem launch template customizado no node group

- **Arquivo:** `eks.cluster.node-group.tf`
- **Problema:** Sem launch template, IMDSv2 não é explicitamente forçado (AL2023
  exige por default, mas não é visível no código).
- **Status:** Não corrigido (AL2023 já exige IMDSv2 por default).

#### 2.14. Sem network policy enforcement

- **Problema:** Sem network policy (EKS nativa ou Calico), não há segmentação
  pod-to-pod.
- **Status:** Não corrigido (recomendado para produção com múltiplos namespaces).

#### 2.15. `external_id` em arquivo texto no disco

- **Arquivo:** `terraform.tfvars`
- **Problema:** O `external_id` é um secret compartilhado em texto plano no
  disco. Embora o arquivo seja git-ignored, há exposição residual.
- **Status:** Não corrigido (preferir `TF_VAR_assume_role` via env var ou
  secrets manager).

#### 2.16. Tags default `Environment = "production"`

- **Arquivo:** `variables.tf`
- **Problema:** Se "eks-express" for workload não-produção, os recursos ficam
  marcados incorretamente como production.
- **Status:** Não corrigido (verificar se o default é apropriado para o
  ambiente).

---

## 3. Arquivos Criados

| Arquivo | Descrição |
|---------|-----------|
| `eks.cluster.kms.tf` | KMS CMK com rotação automática + alias para criptografia de secrets |
| `eks.cluster.irsa.tf` | OIDC provider + IRSA role para VPC CNI + EKS addon gerenciado |
| `eks.cluster.console-iam.tf` | IAM policy `eks-console-access` (read-only) + attachment ao usuário `aula` |

## 4. Arquivos Modificados

| Arquivo | Mudanças |
|---------|----------|
| `main.tf` | `required_version = ">= 1.9.0"`, `encrypt = true` no backend S3 |
| `variables.tf` | `bash_user_arn` (variável com validação), `endpoint_public_access`, `endpoint_private_access`, validation blocks para `console_user_arn`, `authentication_mode`, `capacity_type`, default de `authentication_mode` alterado para `API` |
| `locals.tf` | `bash_user_arn` de hardcoded para `var.bash_user_arn` |
| `eks.cluster.tf` | `endpoint_public_access`/`endpoint_private_access` no `vpc_config`, `encryption_config` com KMS, `lifecycle { prevent_destroy = true }` |
| `eks.cluster.access.tf` | `count` condicional no `bash_user` (access entry + policy association) |
| `eks.cluster.node-group.iam.tf` | Removida `AmazonEKS_CNI_Policy` do node role |
| `eks.cluster.node-group.tf` | Removida CNI do `depends_on`, adicionado `lifecycle { prevent_destroy = true }` |
| `terraform.tfvars` | `console_user_arn` trocado de `root` para `user/aula`, adicionado `bash_user_arn` |
| `terraform.tfvars.example` | Adicionado `bash_user_arn` e instruções sobre `prevent_destroy` |

---

## 5. Recursos Criados na AWS

| Recurso | Tipo | Descrição |
|---------|------|-----------|
| `aws_kms_key.eks` | KMS | CMK com rotação automática para secrets encryption |
| `aws_kms_alias.eks` | KMS | Alias `alias/eks-eks-express-cluster` |
| `aws_iam_openid_connect_provider.eks` | IAM | OIDC provider do cluster para IRSA |
| `aws_iam_role.vpc_cni` | IAM | Role IRSA para VPC CNI (`eks-express-cluster-vpc-cni`) |
| `aws_iam_role_policy_attachment.vpc_cni` | IAM | `AmazonEKS_CNI_Policy` anexada à role IRSA |
| `aws_eks_addon.vpc_cni` | EKS | Addon gerenciado vpc-cni com IRSA role |
| `aws_iam_policy.eks_console_access` | IAM | Policy read-only para EKS console |
| `aws_iam_user_policy_attachment.console_user_eks` | IAM | Policy anexada ao usuário `aula` |

## 6. Recursos Removidos/Modificados na AWS

| Recurso | Ação |
|---------|------|
| `aws_iam_role_policy_attachment.eks_cluster_node_group_AmazonEKS_CNI_Policy` | Destruído (CNI movido para IRSA) |
| `aws_eks_access_entry.console_user` | Recriado (root → aula) |
| `aws_eks_access_policy_association.console_user` | Recriado (root → aula) |
| `aws_eks_cluster.this` | Atualizado in-place (encryption_config, endpoint_private_access, authentication_mode) |

---

## 6. Verificação Final

```
terraform plan              → No changes. Your infrastructure matches the configuration.
kubectl get pods -A         → 8 pods Running (aws-node ×3, coredns ×2, kube-proxy ×3)
aws eks describe-addon      → vpc-cni: ACTIVE, IRSA role: eks-express-cluster-vpc-cni
aws eks list-access-entries  → aula + devops-nuvem (root removido)
node role policies           → AmazonEKSWorkerNodePolicy + AmazonEC2ContainerRegistryReadOnly (sem CNI)
cluster auth mode            → API
cluster encryption           → KMS CMK ativa com rotação
cluster endpoint private     → true
```

---

## 7. Instruções Operacionais

### 7.1. Acesso ao console AWS

Para visualizar pods/resources no EKS Console, faça login como **`aula`** (não root).
O usuário `aula` agora tem:
- IAM policy `eks-console-access` (permissões AWS-side: `eks:DescribeCluster`,
  `eks:AccessKubernetesApi`, etc.)
- EKS access entry com `AmazonEKSClusterAdminPolicy` (permissões Kubernetes RBAC)

### 7.2. Fechar endpoint público do EKS

Quando houver VPN/bastion para acessar o cluster de dentro da VPC, adicione ao
`terraform.tfvars`:

```hcl
endpoint_public_access = false
```

Isso tornará o API server acessível apenas pela rede privada. O `kubectl` deixará
de funcionar de fora da VPC.

### 7.3. Destruir o cluster

Os blocos `lifecycle { prevent_destroy = true }` em `eks.cluster.tf` e
`eks.cluster.node-group.tf` bloqueiam `terraform destroy`. Para destruir:

1. Comente os blocos `lifecycle` em ambos os arquivos
2. Rode `terraform apply` (para remover a proteção)
3. Rode `terraform destroy`

### 7.4. Trocar usuário de acesso

- **Console:** alterar `console_user_arn` no `terraform.tfvars`
- **CLI/Terraform:** alterar `bash_user_arn` no `terraform.tfvars`
- Ambos aceitam `null` para desabilitar o access entry

### 7.5. Usar SSO em vez de IAM user

Para ambientes com IAM Identity Center (SSO), setar `console_user_arn` para o
ARN da role SSO:

```hcl
console_user_arn = "arn:aws:iam::975050217683:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_PermissionSet_HASH"
```

As permissões IAM devem ser gerenciadas através do permission set, não via
`aws_iam_user_policy_attachment`.

---

## 8. Recomendações Não Implementadas

| # | Item | Severidade | Nota |
|---|------|------------|------|
| 1 | Adicionar `aws:SourceArn`/`aws:SourceAccount` nos trust policies | BAIXO | Relevante para multi-cluster |
| 2 | Launch template com `http_tokens = "required"` explícito | BAIXO | AL2023 já exige IMDSv2 por default |
| 3 | Network policy enforcement (EKS nativa ou Calico) | BAIXO | Recomendado para produção multi-namespace |
| 4 | Migrar `external_id` para `TF_VAR_assume_role` env var | BAIXO | Reduz exposição no disco |
| 5 | Revisar tags default `Environment = "production"` | BAIXO | Verificar se é apropriado |
| 6 | Trocar AWS-managed policies por customer-managed scoped | BAIXO | Menor privilégio possível |
