# 🔐 Solução: Credenciais AWS Inválidas

## ❌ Erro Recebido

```
api error InvalidClientTokenId: The security token included in the request is invalid.
```

**Causa:** Suas credenciais AWS estão expiradas, incorretas ou não configuradas.

---

## ✅ Solução

### Opção 1: Usar SSO (AWS Single Sign-On) - RECOMENDADO

Se sua organização usa AWS SSO:

```bash
aws sso login --profile default
```

Isso abrirá um navegador para autenticação. Após login, suas credenciais serão salvas automaticamente.

Verifique:
```bash
aws sts get-caller-identity
```

---

### Opção 2: Configurar com Access Key (Menos Seguro)

Se você tem Access Key ID e Secret Access Key:

```bash
aws configure
```

Responda:
```
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-east-1
Default output format [None]: table
```

---

### Opção 3: Configurar via Variáveis de Ambiente

```bash
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export AWS_DEFAULT_REGION="us-east-1"
```

---

### Opção 4: Usar assume_role com SSO (Para Cross-Account)

Se você precisa asumir um role em outra conta (provavelmente seu caso):

#### 4.1 Configure o perfil SSO

Edite `~/.aws/config`:

```ini
[profile default]
sso_start_url = https://YOUR-SSO-PORTAL.awsapps.com/start
sso_region = us-east-1
sso_account_id = 123456789012
sso_role_name = YourRoleName
region = us-east-1

[profile terraform]
role_arn = arn:aws:iam::ACCOUNT_ID:role/terraform-role
source_profile = default
external_id = YOUR_EXTERNAL_ID
region = us-east-1
```

#### 4.2 Faça login

```bash
aws sso login --profile default
```

#### 4.3 Configure Terraform para usar o perfil

Edite `/home/kali/kenerry/NSSE-IAC/cluster/main.tf`:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # ... seu backend ...
}

provider "aws" {
  region = var.region
  
  # Remova assume_role se está usando SSO
  # assume_role {
  #   role_arn    = var.assume_role.role_arn
  #   external_id = var.assume_role.external_id
  # }
  
  # Use isso ao invés:
  profile = "terraform"
  
  default_tags {
    tags = var.tags
  }
}
```

---

## 🔍 Verificar Credenciais

Depois de configurar, teste:

```bash
# Deve mostrar seu usuário/role
aws sts get-caller-identity

# Deve mostrar um profile válido
aws configure list

# Listar VPCs (teste de conectividade)
aws ec2 describe-vpcs --region us-east-1
```

---

## ⚠️ Problemas Comuns

### "InvalidClientTokenId"

- **Causa:** Access Key expirada ou incorreta
- **Solução:** Gere um novo Access Key no AWS Console

### "ExpiredToken"

- **Causa:** Sessão SSO expirou
- **Solução:** Execute `aws sso login` novamente

### "UnauthorizedOperation"

- **Causa:** Seu usuário não tem permissão
- **Solução:** Peça ao admin para adicionar permissões necessárias

### "NoCredentialsError"

- **Causa:** Nenhuma credencial configurada
- **Solução:** Execute `aws configure` ou `aws sso login`

---

## 📋 Checklist

```bash
✅ aws sts get-caller-identity          # Mostra seu usuário
✅ aws ec2 describe-vpcs                # Lista VPCs
✅ echo $AWS_ACCESS_KEY_ID              # Mostra access key (se usando env vars)
✅ cat ~/.aws/credentials               # Mostra credenciais salvas
✅ cat ~/.aws/config                    # Mostra config de perfil
```

---

## 🚀 Depois de Configurar

Tente novamente:

```bash
cd /home/kali/kenerry/NSSE-IAC/cluster
./force-cleanup.sh
terraform destroy -auto-approve
```

---

## 💡 Dica para o Futuro

Se usar assume_role, adicione em `terraform.tfvars`:

```hcl
assume_role = {
  role_arn    = "arn:aws:iam::ACCOUNT_ID:role/terraform-role"
  external_id = "YOUR_EXTERNAL_ID"
}
```

Não deixe hardcoded no `.tf`!

