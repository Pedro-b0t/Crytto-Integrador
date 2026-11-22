# Segurança (Parte B)

Controles S1 a S8, tratamento dos achados das ferramentas de análise e análise de ameaças da arquitetura implantada ([arquitetura.md](arquitetura.md)).

## Controles obrigatórios

| # | Controle | Status | Onde está | Responsável |
|---|---|---|---|---|
| S1 | Endurecimento do SSH | Implementado no startup script; validar na demonstração D3 | [infra/templates/common.sh](../infra/templates/common.sh) (`harden_ssh`) | Victor (validação), Pedro (script) |
| S2 | Saída restrita | Implementado nas três VMs | [infra/security.tf](../infra/security.tf) | Victor |
| S3 | HTTPS | Implementado | [nginx.https.conf](../nginx.https.conf), [infra/templates/app.sh.tftpl](../infra/templates/app.sh.tftpl) | Pedro |
| S4 | Gestão de segredos | Implementado | [infra/secrets.tf](../infra/secrets.tf), [infra/variables.tf](../infra/variables.tf) (`db_password`) | Pedro |
| S5 | Menor privilégio para as instâncias | Implementado para a senha do banco; falta a permissão do bucket de backup | [infra/iam.tf](../infra/iam.tf) | Pedro, João |
| S6 | Criptografia em repouso | Implementado nos discos; falta o bucket de backup | [infra/kms.tf](../infra/kms.tf), [infra/compute.tf](../infra/compute.tf) | Pedro, João |
| S7 | Análise automatizada | Pendente | `docs/evidencias/` | Ana |
| S8 | Proteção da conta (MFA) | Pendente: captura de tela | `docs/evidencias/` | Pedro |

### S1: endurecimento do SSH

Cada VM recebe, no primeiro boot, o arquivo `/etc/ssh/sshd_config.d/00-crytto-hardening.conf`:

```text
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
```

O OpenSSH do Ubuntu inclui `sshd_config.d/*.conf` no início do `sshd_config` e usa o primeiro valor encontrado; o prefixo `00-` garante precedência sobre os arquivos da imagem. A configuração é validada com `sshd -t` antes do `reload`. Além disso, as VMs aceitam apenas a chave do grupo (`block-project-ssh-keys = true`) e não usam OS Login.

Verificação (resultado esperado: `Permission denied (publickey)`):

```bash
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password crytto@<IP_PUBLICO_BASTION>
```

### S2: saída restrita

As instâncias `vm-bastion`, `vm-app` e `vm-db` recebem regras de egress por tag:

- DNS: TCP e UDP na porta 53.
- HTTP/HTTPS: TCP nas portas 80 e 443.
- PostgreSQL: TCP na porta 5432 apenas da `vm-app` para o CIDR `priv-a`.
- SSH: TCP 22 apenas do `vm-bastion` para o CIDR da VPC (salto para `vm-app` e `vm-db`).
- A regra `deny` de prioridade 65534 bloqueia todo o restante da saída.
- A `vm-db` não possui IP público; sua saída externa ocorre pelo Cloud NAT reservado.

Essa configuração substitui a saída aberta da Entrega 1 e limita movimentação lateral e comunicação com destinos externos não necessários.

### S3: HTTPS

- O nginx da `vm-app` atende em 443 com TLS 1.2 e 1.3. A porta 80 só responde `301` para `https://` (e `/healthz`, reservado a health checks).
- Certificado autoassinado gerado na própria VM pelo startup script, com `subjectAltName` igual ao IP estático da aplicação e validade de 90 dias. A chave privada fica em `/etc/crytto/tls/server.key` (root, 0600) e nunca sai da VM.
- Cabeçalhos `X-Content-Type-Options`, `X-Frame-Options` e `Referrer-Policy`; versão do nginx oculta (`server_tokens off`).
- Não foi usado certificado público porque o grupo não tem domínio próprio. Com um domínio, bastaria trocar o certificado por um do Let's Encrypt (certbot) sem alterar a infraestrutura.

Verificação:

```bash
curl -vk https://<IP_APP>/health          # negociação TLS e {"status":"ok","db":"up"}
curl -sI http://<IP_APP>/                  # HTTP/1.1 301 Moved Permanently, Location: https://...
```

### S4: gestão de segredos

- A senha do PostgreSQL entra no Terraform apenas por `TF_VAR_db_password`. A variável é `sensitive = true` e `ephemeral = true`.
- O valor é gravado no Secret Manager (`crytto-db-password`) pelo argumento write-only `secret_data_wo`, portanto **não aparece no plan, nos outputs nem no `terraform.tfstate`**. Rotação: incrementar `db_password_version`.
- As VMs leem o segredo em tempo de boot pela API do Secret Manager e o gravam apenas em `/etc/crytto/db.env` e `/etc/crytto/app.env` (root, 0600), fora do diretório do código.
- Os arquivos versionados não contêm senha: `.gitignore` bloqueia `*.tfvars`, `*.tfstate`, `.terraform/`, chaves e certificados.

Verificação (D5):

```bash
git grep -n -i "password" -- infra/ docker-compose.gcp.yml   # só nomes de variáveis e recursos, nenhum valor
terraform state show google_secret_manager_secret_version.db_password   # sem o valor da senha
gcloud secrets versions list crytto-db-password
```

### S5: menor privilégio para as instâncias

| VM | Service account | Permissões |
|---|---|---|
| `vm-bastion` | nenhuma | Nenhuma: só repassa SSH |
| `vm-app` | `sa-vm-app` | `roles/secretmanager.secretAccessor` somente no segredo `crytto-db-password` |
| `vm-db` | `sa-vm-db` | `roles/secretmanager.secretAccessor` somente no segredo `crytto-db-password`; gravação no bucket de backup (a definir por João) |

As permissões são concedidas no próprio recurso (IAM do segredo), não no projeto. As VMs obtêm tokens de curta duração do metadata server; nenhuma chave de service account é criada ou gravada nas instâncias. Nenhuma VM usa a service account padrão do Compute Engine (que tem papel de editor no projeto).

### S6: criptografia em repouso

- Key ring `kr-crytto-<sufixo>` e chave `cmek-crytto` no Cloud KMS (`us-central1`), com rotação automática a cada 90 dias.
- Os três discos de boot usam a chave por `kms_key_self_link` ([infra/compute.tf](../infra/compute.tf)). Os dados do PostgreSQL ficam no disco de boot da `vm-db`; snapshots desses discos herdam a mesma chave.
- Apenas o agente de serviço do Compute Engine recebe `roles/cloudkms.cryptoKeyEncrypterDecrypter` na chave.
- O bucket de backup (João) deve usar a mesma chave (output `kms_key_id`), concedendo o papel ao agente de serviço do Cloud Storage.

Verificação:

```bash
gcloud compute disks describe vm-db --zone us-central1-a --format="value(diskEncryptionKey.kmsKeyName)"
```

### S7: análise automatizada

_A preencher por Ana (relatórios de Trivy/Checkov e Gitleaks em `docs/evidencias/`)._

### S8: proteção da conta

_Captura de tela do MFA habilitado, sem dados sensíveis, em `docs/evidencias/` (Pedro)._

## Tratamento dos achados

_A preencher por Ana. Todo achado de severidade alta ou crítica precisa de decisão._

| Achado | Severidade | Recurso | Decisão | Justificativa |
|---|---|---|---|---|

## Análise de ameaças

_A preencher por Ana. No mínimo cinco ameaças concretas à arquitetura do grupo._

| Ameaça | Ativo afetado | Controle aplicado | Risco residual |
|---|---|---|---|
