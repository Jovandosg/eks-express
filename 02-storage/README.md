# Volume EBS existente

Este modulo gerencia o volume `vol-081dcd7fe72d1545d` independentemente do EKS
e da rede. Ele configura gp3 com 3.000 IOPS e throughput padrao de 125 MiB/s,
preservando 4 GiB, us-east-1a, sem criptografia e as tags do antigo PVC
`ebs-claim`. Para o volume importado como gp2, revise o plano antes de aplicar
a migracao para gp3; a alteracao deve ocorrer sem substituir o volume.

## Estado e autenticacao

O estado e local, em `terraform.tfstate`, ignorado pelo Git. Guarde um backup
seguro desse arquivo: perder o estado exige importar o volume novamente.
O antigo bucket `nsse-state-files` nao estava disponivel na importacao.

O provider utiliza a cadeia padrao de credenciais AWS (incluindo `AWS_PROFILE`),
sem assumir automaticamente a role usada pelos outros modulos. A conta permitida
e `975050217683` e a regiao e `us-east-1`.

Na raiz do repositorio:

```bash
terraform -chdir=02-storage init
terraform -chdir=02-storage validate
terraform -chdir=02-storage plan
```

Para a primeira importacao, ou recuperacao de um estado perdido, antes de
qualquer apply:

```bash
terraform -chdir=02-storage import aws_ebs_volume.existing vol-081dcd7fe72d1545d
terraform -chdir=02-storage plan
```

Nao repita a importacao se o volume ja consta em `terraform state list`.
Nao execute apply sem importar o volume: isso criaria outro volume.

## Ciclo de vida

A importacao nao altera os dados nem anexa o volume ao cluster. O manifesto
`../cluster/csi-example-deployment.yml` usa provisionamento dinamico e nao
reutiliza automaticamente este volume. Nao permita que CSI e Terraform
gerenciem simultaneamente a exclusao do mesmo volume.

O destroy de `cluster` ou `networking` nao destroi este volume. Ja
`terraform -chdir=02-storage destroy` **exclui o volume e seus dados**: nao ha
`prevent_destroy`, conforme a escolha de gerenciamento. Faca um snapshot
antes de excluir se precisar preservar os dados.
