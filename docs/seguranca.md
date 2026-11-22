# Seguran├ºa (Parte B)

Controles S1 a S8, tratamento dos achados das ferramentas de an├ílise e an├ílise de amea├ºas da arquitetura implantada ([arquitetura.md](arquitetura.md)).

## Controles obrigat├│rios

| # | Controle | Status | Onde est├í | Respons├ível |
|---|---|---|---|---|
| S1 | Endurecimento do SSH | Implementado no startup script; validar na demonstra├º├úo D3 | [infra/templates/common.sh](../infra/templates/common.sh) (`harden_ssh`) | Victor (valida├º├úo), Pedro (script) |
| S2 | Sa├¡da restrita | Pendente | `infra/security.tf` | Victor |
| S3 | HTTPS | Implementado | [nginx.https.conf](../nginx.https.conf), [infra/templates/app.sh.tftpl](../infra/templates/app.sh.tftpl) | Pedro |
| S4 | Gest├úo de segredos | Implementado | [infra/secrets.tf](../infra/secrets.tf), [infra/variables.tf](../infra/variables.tf) (`db_password`) | Pedro |
| S5 | Menor privil├®gio para as inst├óncias | Implementado para a senha do banco; falta a permiss├úo do bucket de backup | [infra/iam.tf](../infra/iam.tf) | Pedro, Jo├úo |
| S6 | Criptografia em repouso | Implementado nos discos; falta o bucket de backup | [infra/kms.tf](../infra/kms.tf), [infra/compute.tf](../infra/compute.tf) | Pedro, Jo├úo |
| S7 | An├ílise automatizada | Pendente | `docs/evidencias/` | Ana |
| S8 | Prote├º├úo da conta (MFA) | Pendente: captura de tela | `docs/evidencias/` | Pedro |

### S1: endurecimento do SSH

Cada VM recebe, no primeiro boot, o arquivo `/etc/ssh/sshd_config.d/00-crytto-hardening.conf`:

```text
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
```

O OpenSSH do Ubuntu inclui `sshd_config.d/*.conf` no in├¡cio do `sshd_config` e usa o primeiro valor encontrado; o prefixo `00-` garante preced├¬ncia sobre os arquivos da imagem. A configura├º├úo ├® validada com `sshd -t` antes do `reload`. Al├®m disso, as VMs aceitam apenas a chave do grupo (`block-project-ssh-keys = true`) e n├úo usam OS Login.

Verifica├º├úo (resultado esperado: `Permission denied (publickey)`):

```bash
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password crytto@<IP_PUBLICO_BASTION>
```

### S2: sa├¡da restrita

_A preencher por Victor._

### S3: HTTPS

- O nginx da `vm-app` atende em 443 com TLS 1.2 e 1.3. A porta 80 s├│ responde `301` para `https://` (e `/healthz`, reservado a health checks).
- Certificado autoassinado gerado na pr├│pria VM pelo startup script, com `subjectAltName` igual ao IP est├ítico da aplica├º├úo e validade de 90 dias. A chave privada fica em `/etc/crytto/tls/server.key` (root, 0600) e nunca sai da VM.
- Cabe├ºalhos `X-Content-Type-Options`, `X-Frame-Options` e `Referrer-Policy`; vers├úo do nginx oculta (`server_tokens off`).
- N├úo foi usado certificado p├║blico porque o grupo n├úo tem dom├¡nio pr├│prio. Com um dom├¡nio, bastaria trocar o certificado por um do Let's Encrypt (certbot) sem alterar a infraestrutura.

Verifica├º├úo:

```bash
curl -vk https://<IP_APP>/health          # negocia├º├úo TLS e {"status":"ok","db":"up"}
curl -sI http://<IP_APP>/                  # HTTP/1.1 301 Moved Permanently, Location: https://...
```

### S4: gest├úo de segredos

- A senha do PostgreSQL entra no Terraform apenas por `TF_VAR_db_password`. A vari├ível ├® `sensitive = true` e `ephemeral = true`.
- O valor ├® gravado no Secret Manager (`crytto-db-password`) pelo argumento write-only `secret_data_wo`, portanto **n├úo aparece no plan, nos outputs nem no `terraform.tfstate`**. Rota├º├úo: incrementar `db_password_version`.
- As VMs leem o segredo em tempo de boot pela API do Secret Manager e o gravam apenas em `/etc/crytto/db.env` e `/etc/crytto/app.env` (root, 0600), fora do diret├│rio do c├│digo.
- Os arquivos versionados n├úo cont├¬m senha: `.gitignore` bloqueia `*.tfvars`, `*.tfstate`, `.terraform/`, chaves e certificados.

Verifica├º├úo (D5):

```bash
git grep -n -i "password" -- infra/ docker-compose.gcp.yml   # s├│ nomes de vari├íveis e recursos, nenhum valor
terraform state show google_secret_manager_secret_version.db_password   # sem o valor da senha
gcloud secrets versions list crytto-db-password
```

### S5: menor privil├®gio para as inst├óncias

| VM | Service account | Permiss├Áes |
|---|---|---|
| `vm-bastion` | nenhuma | Nenhuma: s├│ repassa SSH |
| `vm-app` | `sa-vm-app` | `roles/secretmanager.secretAccessor` somente no segredo `crytto-db-password` |
| `vm-db` | `sa-vm-db` | `roles/secretmanager.secretAccessor` somente no segredo `crytto-db-password`; grava├º├úo no bucket de backup (a definir por Jo├úo) |

As permiss├Áes s├úo concedidas no pr├│prio recurso (IAM do segredo), n├úo no projeto. As VMs obt├¬m tokens de curta dura├º├úo do metadata server; nenhuma chave de service account ├® criada ou gravada nas inst├óncias. Nenhuma VM usa a service account padr├úo do Compute Engine (que tem papel de editor no projeto).

### S6: criptografia em repouso

- Key ring `kr-crytto-<sufixo>` e chave `cmek-crytto` no Cloud KMS (`us-central1`), com rota├º├úo autom├ítica a cada 90 dias.
- Os tr├¬s discos de boot usam a chave por `kms_key_self_link` ([infra/compute.tf](../infra/compute.tf)). Os dados do PostgreSQL ficam no disco de boot da `vm-db`; snapshots desses discos herdam a mesma chave.
- Apenas o agente de servi├ºo do Compute Engine recebe `roles/cloudkms.cryptoKeyEncrypterDecrypter` na chave.
- O bucket de backup (Jo├úo) deve usar a mesma chave (output `kms_key_id`), concedendo o papel ao agente de servi├ºo do Cloud Storage.

Verifica├º├úo:

```bash
gcloud compute disks describe vm-db --zone us-central1-a --format="value(diskEncryptionKey.kmsKeyName)"
```

### S7: an├ílise automatizada

_A preencher por Ana (relat├│rios de Trivy/Checkov e Gitleaks em `docs/evidencias/`)._

### S8: prote├º├úo da conta

_Captura de tela do MFA habilitado, sem dados sens├¡veis, em `docs/evidencias/` (Pedro)._

## Tratamento dos achados

_A preencher por Ana. Todo achado de severidade alta ou cr├¡tica precisa de decis├úo._

| Achado | Severidade | Recurso | Decis├úo | Justificativa |
|---|---|---|---|---|

## An├ílise de amea├ºas

_A preencher por Ana. No m├¡nimo cinco amea├ºas concretas ├á arquitetura do grupo._

| Amea├ºa | Ativo afetado | Controle aplicado | Risco residual |
|---|---|---|---|
