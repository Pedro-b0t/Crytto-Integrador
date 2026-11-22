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
| S7 | Análise automatizada | Executada parcialmente: Checkov em Ansible e Terraform; Gitleaks executado anteriormente. Revalidação final pendente após integração da rede | `docs/evidencias/` | Ana |
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

Foram utilizadas ferramentas de análise automatizada para identificar possíveis vulnerabilidades e problemas de configuração no projeto.

**Checkov — Ansible:** a análise identificou 4 verificações aprovadas e 3 falhas. Os achados incluem uma senha de banco de dados definida diretamente no arquivo de variáveis e duas verificações de saúde utilizando HTTP local.

**Checkov — Terraform:** a análise identificou 24 verificações aprovadas e 6 falhas. Os achados estão relacionados ao bloqueio de chaves SSH do projeto (3 ocorrências), à presença de IPs públicos (2 ocorrências) e à proteção da chave de criptografia KMS (1 ocorrência).

**Gitleaks:** foi realizada uma análise anterior do histórico do repositório, sem identificação de segredos. Uma nova execução será necessária antes da entrega final, após a integração das alterações dos demais integrantes.

**Evidências:** os relatórios estão armazenados na pasta `docs/evidencias/`, incluindo `checkov-antes.txt`, `checkov-terraform.txt` e `gitleaks-relatorio.json`.

**Limitação:** a validação completa do Terraform ainda depende da integração dos recursos de rede e firewall desenvolvidos em outra branch. Os resultados apresentados correspondem ao código disponível no momento das análises.

### S8: prote├º├úo da conta

_Captura de tela do MFA habilitado, sem dados sens├¡veis, em `docs/evidencias/` (Pedro)._

## Tratamento dos achados

Os achados identificados pelas ferramentas foram analisados considerando
a arquitetura do projeto, os controles existentes e os riscos residuais.
As decisões são registradas como Corrigido, Aceito ou Pendente.

| Achado | Severidade | Recurso | Decisão | Justificativa |
|---|---|---|---|---|
| CKV_SECRET_4 — Senha definida diretamente no código | Não informada pelo Checkov CLI | `infra/ansible/group_vars/all.yml` | Corrigido no arquivo atual; validação funcional pendente | As credenciais fixas foram substituídas por variáveis de ambiente `CRYTTO_DB_PASSWORD` e `CRYTTO_DATABASE_URL`. Uma nova execução do Checkov não apresentou o achado CKV_SECRET_4. Ainda é necessário validar a execução do Ansible com essas variáveis definidas e trocar qualquer senha real anteriormente exposta no histórico Git. |

| CKV_GCP_40 — IP público no bastion | Não informada pelo Checkov CLI | `google_compute_instance.bastion` | Aceito | O bastion precisa de um IP público para permitir o acesso administrativo à infraestrutura. O risco é reduzido pela restrição de SSH ao CIDR autorizado do grupo, autenticação por chave e bloqueio de login root. Permanece o risco de comprometimento de uma chave privada autorizada. |
| CKV_GCP_40 — IP público na aplicação | Não informada pelo Checkov CLI | `google_compute_instance.app` | Aceito | A arquitetura atualmente implantada utiliza acesso direto à aplicação por IP público, sem Load Balancer. O HTTP redireciona para HTTPS, e a proposta de alta disponibilidade prevê retirar o IP público das VMs da aplicação. Enquanto essa mudança não for implementada, a VM continua exposta diretamente à internet. |
| CKV_GCP_32 — Bloqueio de chaves SSH do projeto (3 ocorrências) | Não informada pelo Checkov CLI | `google_compute_instance.bastion`, `google_compute_instance.db` e `google_compute_instance.app` | Aceito provisoriamente — provável falso positivo | O Checkov apontou ausência do bloqueio de chaves SSH nas três VMs. Entretanto, `infra/locals.tf` define `block-project-ssh-keys = "true"` em `local.common_metadata`, utilizado pelas três instâncias em `infra/compute.tf` por meio de `merge()`. A análise estática pode não ter interpretado essa composição. É necessário confirmar a configuração efetiva das VMs no ambiente GCP. |
| CKV_GCP_82 — Proteção contra exclusão da chave KMS | Não informada pelo Checkov CLI | `google_kms_crypto_key.cmek` | Aceito provisoriamente — requer aprovação do grupo | O arquivo `infra/kms.tf` configura `destroy_scheduled_duration = "86400s"`, equivalente a 24 horas. Esse prazo reduz a janela de recuperação em caso de exclusão acidental de uma versão da chave. A configuração pode ser justificada pelo caráter temporário do ambiente acadêmico, mas permanece o risco de perda de acesso aos dados criptografados. Recomenda-se avaliar um prazo maior antes de utilizar a infraestrutura em produção. |
| CKV2_ANSIBLE_1 — Verificações de saúde por HTTP (2 ocorrências) | Não informada pelo Checkov CLI | Verificações de saúde no Ansible | Aceito | As verificações utilizam HTTP para consultar serviços locais por `localhost`, sem transmitir os dados pela internet. O uso de HTTP nesse contexto tem risco reduzido, pois a comunicação ocorre dentro da própria máquina. Permanece o risco caso algum serviço local seja comprometido ou a configuração passe a utilizar endereços externos. |

## An├ílise de amea├ºas

| Amea├ºa | Ativo afetado | Controle aplicado | Risco residual |
|---|---|---|---|
| Ataque de força bruta ou roubo de chave SSH para acessar o bastion e alcançar as VMs internas | Bastion, aplicação e banco de dados | Acesso SSH restrito ao CIDR autorizado do grupo, autenticação por chave, login root desabilitado e bloqueio de chaves SSH do projeto declarado no Terraform | Se uma chave privada autorizada for roubada, um invasor poderá tentar acessar o bastion e alcançar os recursos internos. |
| Alteração indevida do saldo de Crytts de outro usuário por meio da API | API da aplicação, contas dos usuários e saldos de Crytts | Comunicação HTTPS e banco de dados sem acesso público direto, reduzindo a exposição dos dados durante o transporte e o armazenamento | A rota `PUT /api/users/:id/balance` pode permitir alterações de saldo sem verificar adequadamente a autorização do usuário. HTTPS não impede esse tipo de ataque. É necessário implementar autenticação e autorização no backend para garantir que cada usuário só possa realizar operações permitidas. |
| Invasão da VM da aplicação para acessar credenciais e dados do banco | `vm-app`, Secret Manager e `vm-db` | A senha do banco é armazenada no Secret Manager, com acesso limitado às contas de serviço autorizadas. O banco não possui acesso público direto, e a comunicação entre as VMs é controlada por regras de firewall | Se um invasor comprometer a `vm-app`, poderá utilizar as permissões da própria máquina para obter a credencial do banco e tentar acessar ou modificar os dados. Os controles reduzem a exposição, mas não eliminam esse risco. |
| Exclusão ou alteração indevida dos backups após o comprometimento do banco de dados | `vm-db`, arquivos de backup e bucket do Cloud Storage | A arquitetura prevê armazenar os backups em um bucket separado, com criptografia e permissões restritas para a conta de serviço responsável. A implementação desses controles ainda precisa ser confirmada após a integração do trabalho do João | Se um invasor comprometer a VM do banco e conseguir permissões de exclusão ou sobrescrita no bucket, poderá destruir os backups e dificultar a recuperação dos dados. É necessário verificar as permissões efetivas e considerar mecanismos de retenção ou versionamento. |
| Vazamento de senhas, chaves de acesso ou outros segredos pelo repositório GitHub | Repositório Git, credenciais do banco de dados e infraestrutura GCP | Uso do Secret Manager na infraestrutura GCP, variáveis de ambiente para fornecer credenciais e análise do histórico do repositório com Gitleaks | O Ansible local ainda contém uma senha definida diretamente no arquivo de variáveis. Se uma credencial real for publicada no Git, ela poderá continuar acessível pelo histórico mesmo após a remoção do arquivo. É necessário remover credenciais expostas, revogá-las ou alterá-las e executar novamente o Gitleaks antes da entrega. |