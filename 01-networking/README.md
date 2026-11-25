# Backend de estado

O estado de networking usa bloqueio por arquivo no S3 e requer Terraform 1.10
ou superior. Antes da migração, interrompa todas as operações de Terraform e
atualize todos os ambientes que acessam esse estado: os bloqueios por DynamoDB
e por arquivo S3 não se coordenam entre si.

Garanta que as credenciais do backend possam listar o bucket, ler e gravar o
estado e obter, gravar e excluir `networking/terraform.tfstate.tflock`. Depois,
execute `terraform init -reconfigure` neste diretório em cada ambiente antes de
retomar as operações.

A tabela DynamoDB existente não é removida por esta alteração. Não a exclua
enquanto outros backends ou clientes ainda dependerem dela.
