# Segurança (Parte B)

Controles S1 a S8, tratamento dos achados das ferramentas de análise e análise de ameaças da arquitetura implantada ([arquitetura.md](arquitetura.md)).

## Controles obrigatórios

| # | Controle | Status | Onde está | Responsável |
|---|---|---|---|---|
| S1 | Endurecimento do SSH | Implementado no startup script; validar na demonstração D3 | [infra/templates/common.sh](../infra/templates/common.sh) (`harden_ssh`) | Victor (validação), Pedro (script) |
| S2 | Saída restrita | Implementado nas três VMs | [infra/security.tf](../infra/security.tf) | Victor |
| S3 | HTTPS | Implementado | [nginx.https.conf](../nginx.https.conf), [infra/templates/app.sh.tftpl](../infra/templates/app.sh.tftpl) | Pedro |
| S4 | Gestão de segredos | Implementado | [infra/secrets.tf](../infra/secrets.tf), [infra/variables.tf](../infra/variables.tf) (`db_password`) | Pedro |
| S5 | Menor privilégio para as instâncias | Implementado: senha do banco e gravação de backup | [infra/iam.tf](../infra/iam.tf) | Pedro, João |
| S6 | Criptografia em repouso | Implementado nos discos e no bucket de backup | [infra/kms.tf](../infra/kms.tf), [infra/compute.tf](../infra/compute.tf), [infra/backup.tf](../infra/backup.tf) | Pedro, João |
| S7 | Análise automatizada | Executada: Checkov (Ansible e Terraform), Trivy (Terraform com rede e firewall) e Gitleaks (histórico). Repetir o Gitleaks antes da tag `entrega-2` | [docs/evidencias/](evidencias/) | Ana |
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
| `vm-db` | `sa-vm-db` | `roles/secretmanager.secretAccessor` somente no segredo `crytto-db-password`; `roles/storage.objectCreator` somente no bucket de backup (cria objetos; não lista, lê, sobrescreve nem apaga) |

As permissões são concedidas no próprio recurso (IAM do segredo), não no projeto. As VMs obtêm tokens de curta duração do metadata server; nenhuma chave de service account é criada ou gravada nas instâncias. Nenhuma VM usa a service account padrão do Compute Engine (que tem papel de editor no projeto).

### S6: criptografia em repouso

- Key ring `kr-crytto-<sufixo>` e chave `cmek-crytto` no Cloud KMS (`us-central1`), com rotação automática a cada 90 dias.
- Os três discos de boot usam a chave por `kms_key_self_link` ([infra/compute.tf](../infra/compute.tf)). Os dados do PostgreSQL ficam no disco de boot da `vm-db`; snapshots desses discos herdam a mesma chave.
- Apenas o agente de serviço do Compute Engine recebe `roles/cloudkms.cryptoKeyEncrypterDecrypter` na chave.
- O bucket de backup usa a mesma chave como `default_kms_key_name` ([infra/backup.tf](../infra/backup.tf)); o agente de serviço do Cloud Storage recebe `roles/cloudkms.cryptoKeyEncrypterDecrypter` na chave. Cada cópia gravada herda a chave (`gcloud storage objects describe ... --format="value(kms_key)"`).

Verificação:

```bash
gcloud compute disks describe vm-db --zone us-central1-a --format="value(diskEncryptionKey.kmsKeyName)"
```

### S7: análise automatizada

Ferramentas usadas e relatórios em [docs/evidencias/](evidencias/):

| Ferramenta | Escopo | Resultado | Relatório |
|---|---|---|---|
| Checkov 3.4.5 | Ansible (`infra/ansible/`) | 4 aprovadas, 3 falhas: senha fixa em `group_vars/all.yml` e dois health checks por HTTP local | `checkov-antes.txt` |
| Checkov 3.4.5 | Terraform (`infra/*.tf`) | 24 aprovadas, 6 falhas: IP público (2), bloqueio de chaves SSH do projeto (3) e proteção contra exclusão da chave KMS (1) | `checkov-terraform.txt` |
| Trivy 0.76.2 | Terraform completo, com rede, firewall e bucket de backup | 2 altas (IP público), 6 médias (OS Login desativado, flow logs, versionamento do bucket) e 2 baixas (VPC flow logs). Nenhuma crítica | `trivy-terraform.txt` |
| Gitleaks | Histórico completo do Git | Nenhum segredo encontrado | `gitleaks-relatorio.json`, `gitleaks-final.json` |

O Checkov sem conta na plataforma Prisma Cloud não informa severidade; por isso a severidade da tabela de achados vem do Trivy quando a mesma regra foi apontada pelas duas ferramentas. O Gitleaks deve ser executado novamente sobre o histórico final, imediatamente antes da tag `entrega-2`.

**Demonstração D5:** achado corrigido `CKV_SECRET_4` (senha fixa) e achado aceito `GCP-0031`/`CKV_GCP_40` (IP público do bastion).
### S8: proteção da conta

_Captura de tela do MFA habilitado, sem dados sensíveis, em `docs/evidencias/` (Pedro)._

## Tratamento dos achados

Os achados identificados pelas ferramentas foram analisados considerando
a arquitetura do projeto, os controles existentes e os riscos residuais.
Todo achado de severidade alta ou crítica tem decisão registrada (Corrigido ou Aceito).

| Achado | Severidade | Recurso | Decisão | Justificativa |
|---|---|---|---|---|
| CKV_SECRET_4: senha do banco escrita no código | Não informada pelo Checkov (credencial em texto claro) | `infra/ansible/group_vars/all.yml` | **Corrigido** | A senha fixa foi substituída pelas variáveis de ambiente `CRYTTO_DB_PASSWORD` e `CRYTTO_DATABASE_URL`, e uma nova execução do Checkov não apresentou mais o achado. Na nuvem a senha nunca esteve em arquivo: vem de `TF_VAR_db_password` e do Secret Manager (S4). O valor removido (`crytto`) era apenas a senha padrão do ambiente local com Vagrant, não usada na GCP |
| GCP-0031 / CKV_GCP_40: instância com IP público | **Alta** (Trivy) | `google_compute_instance.bastion` | **Aceito** | O bastion precisa de IP público para o acesso administrativo (R6, ADR-001). O SSH só aceita o CIDR autorizado (R7), apenas chave e sem root (S1). Risco residual: comprometimento da chave privada de um integrante |
| GCP-0031 / CKV_GCP_40: instância com IP público | **Alta** (Trivy) | `google_compute_instance.app` | **Aceito** | A arquitetura implantada não tem load balancer, então a aplicação é acessada pelo IP da `vm-app`. Só 80 e 443 estão abertos, e o 80 apenas redireciona para HTTPS (S3); SSH só a partir do bastion. Na proposta de HA as VMs da aplicação ficam sem IP público, atrás do load balancer |
| GCP-0036: OS Login desativado (3 ocorrências) | Média (Trivy) | `google_compute_instance.bastion`, `.app` e `.db` | **Aceito** | Decisão do ADR-001: acesso por chave SSH do grupo através do bastion, sem OS Login. Chaves de projeto bloqueadas e console serial desativado |
| CKV_GCP_32: bloqueio de chaves SSH do projeto (3 ocorrências) | Não informada pelo Checkov | `google_compute_instance.bastion`, `.app` e `.db` | **Aceito (falso positivo)** | `block-project-ssh-keys = "true"` está em `local.common_metadata` ([infra/locals.tf](../infra/locals.tf)) e é aplicado às três VMs por `merge()` em [infra/compute.tf](../infra/compute.tf). O Checkov não avalia essa composição. Conferível após o apply com `gcloud compute instances describe vm-app --format="value(metadata.items)"` |
| CKV_GCP_82: chave KMS sem proteção contra exclusão | Não informada pelo Checkov | `google_kms_crypto_key.cmek` | **Aceito** | A regra pede `lifecycle { prevent_destroy = true }`, o que impediria o `terraform destroy` obrigatório após a apresentação (seção 11 do enunciado). Os discos cifrados pela chave são destruídos junto com o ambiente, e os backups não dependem dela para restauração. Em produção, a proteção seria habilitada e o `destroy_scheduled_duration` aumentado |
| GCP-0076 / GCP-0029: sub-redes sem flow logs (2 ocorrências cada) | Média e baixa (Trivy) | `google_compute_subnetwork.pub_a` e `.priv_a` | **Aceito** | Os flow logs geram custo por volume de log e não são exigidos no escopo. Risco residual: sem registro de fluxos para investigar um incidente de rede |
| GCP-0078: bucket sem versionamento | Média (Trivy) | `google_storage_bucket.backup` | **Aceito** | O versionamento foi desativado de propósito: a política mínima exige expiração em até 2 dias, e versões não correntes ficariam retidas além disso. A proteção contra sobrescrita e exclusão vem da permissão: a `sa-vm-db` só cria objetos e cada cópia tem nome único (data e hora) |
| CKV2_ANSIBLE_1: health check por HTTP (2 ocorrências) | Não informada pelo Checkov | `infra/ansible/playbook.yml` (Validar backend e Validar frontend) | **Aceito** | A verificação acessa `localhost` dentro da própria VM local, sem passar pela rede; o playbook é usado apenas no ambiente local com Vagrant |
## Análise de ameaças

| Ameaça | Ativo afetado | Controle aplicado | Risco residual |
|---|---|---|---|
| Ataque de força bruta ou roubo de chave SSH para acessar o bastion e alcançar as VMs internas | Bastion, aplicação e banco de dados | Acesso SSH restrito ao CIDR autorizado do grupo, autenticação por chave, login root desabilitado e bloqueio de chaves SSH do projeto declarado no Terraform | Se uma chave privada autorizada for roubada, um invasor poderá tentar acessar o bastion e alcançar os recursos internos. |
| Alteração indevida do saldo de Crytts de outro usuário por meio da API | API da aplicação, contas dos usuários e saldos de Crytts | Comunicação HTTPS e banco de dados sem acesso público direto, reduzindo a exposição dos dados durante o transporte e o armazenamento | A rota `PUT /api/users/:id/balance` pode permitir alterações de saldo sem verificar adequadamente a autorização do usuário. HTTPS não impede esse tipo de ataque. É necessário implementar autenticação e autorização no backend para garantir que cada usuário só possa realizar operações permitidas. |
| Invasão da VM da aplicação para acessar credenciais e dados do banco | `vm-app`, Secret Manager e `vm-db` | A senha do banco é armazenada no Secret Manager, com acesso limitado às contas de serviço autorizadas. O banco não possui acesso público direto, e a comunicação entre as VMs é controlada por regras de firewall | Se um invasor comprometer a `vm-app`, poderá utilizar as permissões da própria máquina para obter a credencial do banco e tentar acessar ou modificar os dados. Os controles reduzem a exposição, mas não eliminam esse risco. |
| Exclusão ou alteração indevida dos backups após o comprometimento do banco de dados | `vm-db`, arquivos de backup e bucket do Cloud Storage | Backups em bucket separado da VM, com CMEK (S6). A `sa-vm-db` tem só `roles/storage.objectCreator`: testado na `vm-db`, listar, ler e apagar retornam 403 (S5) | O invasor ainda pode gravar arquivos novos (lixo) no bucket e impedir backups futuros. Uma conta com papel de dono no projeto consegue apagar o bucket; em produção, usar bucket lock e projeto separado para os backups ([backup.md](backup.md), B6) |
| Vazamento de senhas, chaves de acesso ou outros segredos pelo repositório GitHub | Repositório Git, credenciais do banco de dados e infraestrutura GCP | Uso do Secret Manager na infraestrutura GCP, variáveis de ambiente para fornecer credenciais e análise do histórico do repositório com Gitleaks | Se uma credencial real for publicada no Git, ela continua acessível pelo histórico mesmo após a remoção do arquivo e precisa ser revogada. A senha padrão do Vagrant que existia no histórico (`crytto`) nunca foi usada na GCP. O Gitleaks é executado novamente antes da tag `entrega-2`. |
