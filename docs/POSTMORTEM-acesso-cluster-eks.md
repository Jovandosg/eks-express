# Pós-Mortem — Indisponibilidade de Acesso ao Cluster EKS `eks-express-cluster`

**Data do incidente:** 03/11/2026
**Ambiente:** Produção (AWS conta `975050217683`, região `us-east-1`)
**Serviço afetado:** Cluster EKS `eks-express-cluster` / acesso via `kubectl`
**Severidade:** Alta (acesso total ao cluster indisponível)
**Status:** Resolvido

---

## 1. Resumo

O usuário relatou não conseguir visualizar recursos do cluster EKS (pods, Deployments,
DaemonSets). A investigação revelou que o problema **não era de permissão/RBAC**, mas sim
que **toda a infraestrutura estava ausente**: o bucket de estado do Terraform, a VPC e o
próprio cluster EKS não existiam na AWS. O `kubectl` apontava para um endpoint de cluster
destruído, cujo DNS não resolvia mais.

Após recriar a cadeia completa (`backend → networking → cluster`) e corrigir a política de
acesso EKS, o acesso foi totalmente restaurado.

---

## 2. Impacto

- **Recursos invisíveis:** pods, Deployments, DaemonSets, nodes, services e namespaces
  inacessíveis via `kubectl`.
- **Alcance:** qualquer operação de plataforma/DevOps sobre o cluster estava bloqueada.
- **Duração:** até a recriação da infraestrutura (aprox. 11 minutos de apply do cluster +
  propagação).

---

## 3. Linha do Tempo

| Hora | Evento |
|------|--------|
| T+0 | Usuário relata não conseguir ver recursos do cluster EKS. |
| T+0 | Verificação inicial: `aws sts get-caller-identity` com profile `default` → `InvalidClientTokenId`. |
| T+1 | Teste individual dos 4 profiles AWS: `default` ❌ e `bia` ❌ inválidos; `aula` ✅ e `devops-nuvem` ✅ válidos. |
| T+2 | `aws eks list-clusters` retorna `[]` em `us-east-1` e demais regiões — cluster não existe. |
| T+3 | Bucket S3 de estado `nsse-state-files` → `NoSuchBucket`; tabela DynamoDB ausente; `terraform state list` do backend vazio. |
| T+4 | Nenhuma VPC com tag `Project=eks-express` encontrada — networking ausente. |
| T+5 | `kubectl get nodes` no contexto atual falha: DNS `no such host` (endpoint de cluster destruído). |
| **Diagnóstico fechado** | Causa raiz = infraestrutura nunca provisionada (ou destruída), com kubeconfig apontando para cluster inexistente. |
| T+6 | `terraform apply` backend → 3 recursos criados (bucket + versioning + DynamoDB). |
| T+7 | `terraform apply` networking → 17 recursos criados (VPC, subnets, IGW, 2 NAT GW, route tables). |
| T+8 | `terraform apply` cluster → 10 recursos criados (EKS em ~7m12s, node group em ~1m47s, access entry). |
| T+9 | `aws eks update-kubeconfig` com profile `devops-nuvem`. Pods/Deployments/DaemonSets voltam a aparecer. |
| T+10 | Detectado gap: `kubectl get nodes` → `Forbidden`. `AmazonEKSAdminPolicy` não concede `nodes`. |
| T+11 | Troca da política para `AmazonEKSClusterAdminPolicy` + `terraform apply`. Nodes liberados. |
| **Resolvido** | Validação final: 3 nós, 8 pods, Deployments, DaemonSets, services e namespaces acessíveis. |

---

## 4. Causa Raiz

### Principal
A infraestrutura EKS não estava provisionada na AWS. Concretamente:

1. **Backend de estado ausente** — o bucket S3 `nsse-state-files` e a tabela DynamoDB
   `nsse-state-files` não existiam. Sem o backend, o estado do Terraform foi perdido e o
   módulo `cluster` não conseguia ler o `terraform_remote_state` de networking.
2. **Networking ausente** — nenhuma VPC/subnet do projeto existia.
3. **Cluster ausente** — `aws eks list-clusters` retornava vazio em todas as regiões
   verificadas.

O `kubeconfig` em `~/.kube/config` mantinha o contexto `eks-express-cluster` apontando
para o endpoint `A36D10F7181282F59F760E1D5F520925.gr7.us-east-1.eks.amazonaws.com`, que
não resolvia mais no DNS — sintoma clássico de cluster destruído ou nunca criado.

### Secundária (credenciais)
- Profiles `default` e `bia` tinham credenciais inválidas
  (`InvalidClientTokenId` — chaves expiradas/rotadas).
- Havia um typo em `~/.aws/config` no profile `default`: `aws_access_Key_id` (K
  maiúsculo), que deveria ser `aws_access_key_id`. Não causou falha direta (a AWS lê as
  chaves de `~/.aws/credentials`), mas indica configuração descuidada.

### Terciária (RBAC de nodes)
Mesmo após recriar o cluster, `kubectl get nodes` continuava proibido. A política
`AmazonEKSAdminPolicy` associada ao usuário `devops-nuvem` **intencionalmente não inclui o
recurso `nodes`** (confirmado na
[documentação oficial da AWS](https://docs.aws.amazon.com/eks/latest/userguide/access-policy-permissions.html)).
Ela concede pods, Deployments, DaemonSets, services, namespaces, secrets, etc., mas não
`nodes` nem `persistentvolumes`.

---

## 5. Fatores Contribuintes

- **Ausência de bloqueio/validação de estado:** sem o bucket de backend, o Terraform não
  detectava que a infraestrutura existente e a esperada divergiam — o estado simplesmente
  sumiu, fazendo o Terraform "achar" que nada existia.
- **Kubeconfig obsoleto não limpo:** o contexto de um cluster destruído permaneceu ativo,
  mascarando a causa real com um erro de DNS em vez de uma mensagem clara de "cluster não
  encontrado".
- **Escolha de política de acesso subótima:** `AmazonEKSAdminPolicy` é voltada a escopo de
  namespace, não a administração de cluster inteiro. Para um usuário DevOps com escopo
  `cluster`, a política correta é `AmazonEKSClusterAdminPolicy`.
- **Rotação de credenciais não acompanhada:** dois dos quatro profiles tinham chaves
  inválidas.

---

## 6. Resolução

1. **Recriação da cadeia de dependências** (na ordem obrigatória `backend → networking →
   cluster`), usando o profile `devops-nuvem` (base) com `assume_role` para
   `terraform-role`:
   - `backend/`: S3 `nsse-state-files` + versioning + DynamoDB (3 recursos).
   - `networking/`: VPC `nsse-vpc` (10.0.0.0/24), 2 subnets públicas, 2 privadas, IGW,
     2 NAT gateways, route tables (17 recursos).
   - `cluster/`: EKS `eks-express-cluster` v1.37 + node group (3 × t3.medium) + access
     entry para `devops-nuvem` (10 recursos).
2. **Regeneração do kubeconfig** com o profile correto:
   `aws eks update-kubeconfig --name eks-express-cluster --profile devops-nuvem`.
3. **Correção da política de acesso EKS** em `cluster/eks.cluster.access.tf`:
   substituição de `AmazonEKSAdminPolicy` por `AmazonEKSClusterAdminPolicy` e reapply.
4. **Validação final** confirmou acesso a nodes, pods, Deployments, DaemonSets, services,
   namespaces e secrets.

### Estado final validado

```
NODES:        3 (ip-10-0-0-109/44/48)  Ready  v1.37.1
PODS -A:      8  (aws-node ×3, coredns ×2, kube-proxy ×3)
DEPLOYMENTS:  coredns (kube-system)
DAEMONSETS:   aws-node, kube-proxy
SERVICES:     kubernetes, eks-extension-metrics-api, kube-dns
auth can-i:   list nodes/pods/deployments/daemonsets/services/namespaces/secrets -> yes
```

---

## 7. Lições Aprendidas

- **Validar a existência real antes de depurar permissões.** Um erro de DNS no `kubectl`
  (`no such host`) indica cluster ausente — diferente de um `Forbidden`, que indica RBAC.
  Confundir os dois leva a depurar a camada errada.
- **O backend de estado é infraestrutura crítica.** Se o bucket/dynamo do estado some,
  todo o rastreio do que existe desaparece. O backend deve ser tratado como recurso de
  produção e monitorado.
- **`AmazonEKSAdminPolicy` ≠ cluster-admin.** Ela exclui `nodes` e `persistentvolumes`
  propositalmente. Para administração de cluster inteiro, use
  `AmazonEKSClusterAdminPolicy`.
- **Limpar contextos de kubeconfig obsoletos** evita diagnóstico enganoso.
- **Profiles AWS devem ser auditados** periodicamente; chaves rotadas invalidam silenciosamente.

---

## 8. Itens de Ação

| # | Item | Responsável | Prioridade |
|---|------|-------------|------------|
| 1 | Corrigir typo `aws_access_Key_id` → `aws_access_key_id` no `~/.aws/config` | DevOps | Baixa |
| 2 | Rotar/remover credenciais inválidas dos profiles `default` e `bia` | DevOps | Média |
| 3 | Adicionar verificação de existência do bucket de estado a um pipeline/CI (fail-fast se `nsse-state-files` sumir) | DevOps | Alta |
| 4 | Documentar a ordem de apply `backend → networking → cluster` no README do repositório | DevOps | Média |
| 5 | Considerar `AmazonEKSClusterAdminPolicy` como padrão para access entries de admin com escopo `cluster` (ou criar RBAC customizado com escopo menor se segurança exigir) | DevOps | Média |
| 6 | Remover contextos de kubeconfig de clusters destruídos após `terraform destroy` | DevOps | Baixa |
| 7 | Avaliar proteção contra destruição acidental (ex.: `prevent_destroy` no lifecycle do bucket de estado) | DevOps | Média |

---

## 9. Arquivos Modificados

- `cluster/eks.cluster.access.tf` — política alterada de
  `AmazonEKSAdminPolicy` → `AmazonEKSClusterAdminPolicy`.

## 10. Recursos Criados na AWS

- S3 bucket `nsse-state-files` (com versioning) + tabela DynamoDB `nsse-state-files`
- VPC `nsse-vpc`, 2 subnets públicas, 2 privadas, IGW, 2 NAT gateways, 4 route table
  associations
- EKS `eks-express-cluster` (v1.37) + node group `eks-express-node-group` (3 × t3.medium)
  + IAM roles do cluster e do node group
- EKS access entry + access policy association para `arn:aws:iam::975050217683:user/devops-nuvem`
