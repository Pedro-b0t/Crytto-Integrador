# Crytto RPG Platform v2

## Grupo

Projeto Integrador, Uniamérica Descomplica. Professor: Gildomiro Bairros.

| Integrante | Papel |
|---|---|
| Pedro Henrique de Oliveira | Product Owner |
| Victor Nascimento Silva | Scrum Master |
| Ana Luiza Ripoli Theodorovitz | Desenvolvedora |
| João Pedro Foster Ruiz | Desenvolvedor |

Documentação da Entrega 1: [docs/arquitetura.md](docs/arquitetura.md), ADRs em [docs/adr/](docs/adr/), custos em [docs/custos/](docs/custos/) e declaração de uso de IA em [IA.md](IA.md).

## Entrega 2: Implantação na GCP com Terraform

Divisão de tarefas entre os integrantes: [docs/TAREFAS-ENTREGA2.md](docs/TAREFAS-ENTREGA2.md).

Documentação desta entrega: [docs/seguranca.md](docs/seguranca.md), [docs/alta-disponibilidade.md](docs/alta-disponibilidade.md), [docs/backup.md](docs/backup.md), [docs/errata.md](docs/errata.md) e evidências em `docs/evidencias/`.

> ⚠️ **Aviso de custos.** Este ambiente gera custos pagos pelo grupo; a instituição não oferece créditos. O Cloud NAT e os IPs externos reservados são cobrados por hora, **mesmo sem tráfego**. Configure o alerta de orçamento no Cloud Billing **antes do primeiro `apply`**, mantenha a infraestrutura ligada apenas durante testes e apresentação e execute `terraform destroy` ao final de cada sessão. Estimativas: cenário A (24 h/dia) US$ 49,93 por mês; cenário B (80 h de trabalho) US$ 9,95 no período (ver [docs/arquitetura.md](docs/arquitetura.md#59-estimativa-de-custos)).

### Pré-requisitos

1. Conta GCP com faturamento ativo, MFA habilitado e alerta de orçamento configurado (evidências em `docs/evidencias/`).
2. [Terraform](https://developer.hashicorp.com/terraform/install) **1.17.2**, versão fixada em [infra/versions.tf](infra/versions.tf). Os providers (`google` 6.50.0 e `random` 3.9.1) são baixados pelo `terraform init` conforme o [.terraform.lock.hcl](infra/.terraform.lock.hcl) versionado.
3. [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) autenticado. As credenciais ficam fora do código:

   ```bash
   gcloud auth application-default login
   gcloud config set project <PROJECT_ID>
   gcloud auth application-default set-quota-project <PROJECT_ID>
   # APIs mínimas para o Terraform conseguir habilitar as demais (compute, kms, secret manager, iam)
   gcloud services enable serviceusage.googleapis.com cloudresourcemanager.googleapis.com
   ```

4. Par de chaves SSH do grupo. A chave pública é informada ao Terraform; **a chave privada nunca entra no repositório**:

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/chave-grupo -C "crytto-grupo"
   ```

5. IP público de quem vai administrar, para liberar o SSH no bastion (`curl -s https://ifconfig.me`).

### Configuração das variáveis

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # terraform.tfvars é ignorado pelo Git
```

Edite `terraform.tfvars` com projeto, região, CIDRs, tipos de instância, CIDR autorizado para SSH (`x.x.x.x/32`, nunca `0.0.0.0/0`) e caminho da chave pública. A descrição de cada variável está em [infra/variables.tf](infra/variables.tf).

A senha do banco **não** vai no `terraform.tfvars`. A variável `db_password` é `sensitive` e `ephemeral`: é fornecida por variável de ambiente, gravada no Secret Manager por argumento write-only e **não fica no state**. Use 16+ caracteres com letras, números, `_` ou `-`:

```bash
export TF_VAR_db_password="$(openssl rand -hex 24)"     # Linux/macOS
$env:TF_VAR_db_password = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')   # PowerShell
```

A variável precisa estar definida em todo `plan`, `apply` e `destroy`. Depois do primeiro apply, o valor real fica só no Secret Manager; um valor diferente em execuções seguintes não altera a senha, a menos que `db_password_version` seja incrementada.

### Criar a infraestrutura (apply)

```bash
cd infra
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
terraform output
```

A criação do Cloud NAT pode levar alguns minutos. Os outputs mostram o IP público do bastion, o IP público do NAT, os IPs privados das VMs, a URL da aplicação e os comandos SSH prontos.

### Instalar a aplicação nas instâncias

A instalação é **automatizada**: o Terraform grava em cada VM um startup script ([infra/templates/](infra/templates/)) que a GCP executa como root a cada boot. Não é preciso rodar nada manualmente; os passos abaixo servem para acompanhar a instalação e para repeti-la à mão, se necessário.

**1. Acompanhar a instalação** (a `vm-db` fica pronta em ~3 min; a `vm-app` leva ~10 min porque compila o frontend):

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/chave-grupo
$(terraform output -raw ssh_db)  sudo journalctl -u google-startup-scripts.service -f
$(terraform output -raw ssh_app) sudo journalctl -u google-startup-scripts.service -f
```

A instalação terminou quando aparecer `[crytto-startup] PostgreSQL pronto` (vm-db) e `[crytto-startup] Aplicação pronta em https://<IP>` (vm-app).

**2. Verificar a aplicação:**

```bash
curl -k  "$(terraform output -raw app_url)/health"       # {"status":"ok","db":"up"}
curl -sI "http://$(terraform output -raw app_public_ip)/" # 301 para https://
```

Abra `terraform output -raw app_url` no navegador e aceite o certificado autoassinado. Funcionalidade verificável: criar um usuário e um personagem, recarregar a página e confirmar que continuam lá (gravados no PostgreSQL da `vm-db`).

**3. Reexecutar a instalação** (por exemplo, após mudar `app_repo_ref`): `sudo google_metadata_script_runner startup` na VM. O script é idempotente.

**Procedimento manual equivalente**, na ordem em que o script executa (todos os comandos como root, `sudo -i`):

| # | VM | Passo | Comando principal |
|---|---|---|---|
| 1 | todas | Endurecimento do SSH (S1) | criar `/etc/ssh/sshd_config.d/00-crytto-hardening.conf` com `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin no`; `sshd -t && systemctl reload ssh` |
| 2 | db, app | Instalar Docker Engine e o plugin Compose | repositório oficial `download.docker.com` + `apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin` |
| 3 | db | Ler a senha do Secret Manager (S4/S5) | `gcloud secrets versions access latest --secret=crytto-db-password` (usa a service account da VM) |
| 4 | db | Gravar `/etc/crytto/db.env` (0600) | `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` |
| 5 | db | Subir o PostgreSQL | `docker run -d --name crytto-db --restart unless-stopped --env-file /etc/crytto/db.env -v /var/lib/crytto/pgdata:/var/lib/postgresql/data -p 5432:5432 postgres:16-alpine` |
| 6 | app | Clonar o código | `git clone https://github.com/Pedro-b0t/Crytto-Integrador.git /opt/crytto && git -C /opt/crytto checkout <ref>` |
| 7 | app | Gravar `/etc/crytto/app.env` (0600) | `DATABASE_URL=postgres://crytto:<senha>@10.20.10.10:5432/crytto`, `PGSSL=false`, `FRONTEND_URL=https://<IP_APP>` |
| 8 | app | Certificado autoassinado (S3) | `openssl req -x509 -nodes -newkey rsa:2048 -days 90 -keyout /etc/crytto/tls/server.key -out /etc/crytto/tls/server.crt -subj "/CN=<IP_APP>" -addext "subjectAltName=IP:<IP_APP>"` |
| 9 | app | Subir frontend (nginx 80/443) e backend | `cd /opt/crytto && docker compose -f docker-compose.gcp.yml up -d --build` |

A configuração usada na nuvem está em [docker-compose.gcp.yml](docker-compose.gcp.yml) e [nginx.https.conf](nginx.https.conf). Os arquivos `docker-compose.yml`, `nginx.conf` e o Ansible continuam servindo à execução local com Vagrant.

Acesso às instâncias pelo bastion (o usuário é `crytto`, variável `ssh_user`):

```bash
ssh crytto@<IP_PUBLICO_BASTION>
ssh -J crytto@<IP_PUBLICO_BASTION> crytto@<IP_PRIVADO>
```

### Destruir a infraestrutura (destroy)

```bash
cd infra
terraform destroy
```

Depois, confirme no console (somente consulta) que não restam Cloud NAT, IPs externos, discos, snapshots nem buckets. Buckets com objetos podem impedir a destruição; consulte a documentação do provider (`force_destroy`). O key ring do Cloud KMS não pode ser apagado na GCP (é só removido do state, sem custo); as versões da chave são destruídas 24 h após o destroy.

### Divisão das demonstrações

| Etapa | Conteúdo | Quem conduz | Tempo |
|---|---|---|---|
| D1 | `terraform plan` sem alterações pendentes e `terraform output` | Pedro Henrique de Oliveira | 0,5 min |
| D2 | Aplicação por HTTPS, executando a funcionalidade verificável | Pedro Henrique de Oliveira | 1 min |
| D3 | SSH no bastion, acesso à instância privada via bastion e recusa de autenticação por senha | Victor Nascimento Silva | 1,5 min |
| D4 | Saída da instância privada pelo IP do NAT, instância privada sem IP público e SSH restrito ao CIDR autorizado | Victor Nascimento Silva | 0,5 min |
| D5 | Segredos fora do código e relatório de análise com um achado corrigido e um aceito | Ana Luiza Ripoli Theodorovitz | 1 min |
| D6 | Política mínima de backup (mecanismo, retenção, criptografia e cópia existente) e custo anual da política GFS | João Pedro Foster Ruiz | 1,5 min |
| D7 | Diagrama da proposta de alta disponibilidade e análise de custo | Ana Luiza Ripoli Theodorovitz | 1,5 min |
| Defesa técnica | Perguntas do professor a integrantes escolhidos aleatoriamente | Todos | 2,5 min |

## Execução local com Vagrant (versão anterior)

As seções abaixo descrevem a execução local em VMs VirtualBox, usada antes da implantação na GCP.

## Visão geral

Versão independente do projeto original, preparada para execução e deploy em VM com automação de infraestrutura.

## Objetivo da v2

- Manter o projeto original intacto (Cloud Run).
- Disponibilizar uma versão isolada focada em VM.
- Automatizar provisionamento e configuração com Vagrant + Ansible.

## Stack técnica

- Frontend: React 18 + TypeScript + Vite, servido por nginx.
- Backend: Node.js + Express.
- Banco: Postgres 16.
- Orquestração local/VM: Docker Compose.
- Provisionamento da VM: Vagrant (VirtualBox).
- Configuração da VM: Ansible (agentless).

## Estrutura de automação

- `Vagrantfile`: cria e configura 2 VMs Ubuntu (app e db).
- `infra/ansible/inventory.ini`: inventário/hosts e conexão SSH.
- `infra/ansible/group_vars/all.yml`: variáveis parametrizáveis.
- `infra/ansible/templates/app.env.j2`: template dinâmico de ambiente.
- `infra/ansible/playbook.yml`: provisionamento idempotente e deploy da stack.
- `infra/ansible/README.md`: guia separado da automação Ansible.
- `deploy.ps1` / `deploy.sh`: execução automatizada ponta a ponta.

## Pré-requisitos

1. VirtualBox instalado.
2. Vagrant instalado.
3. Docker não é obrigatório no host, pois será instalado nas VMs.
4. Ansible é opcional no Windows: o `deploy.ps1` usa o provisionamento interno do Vagrant.

Para usar o playbook Ansible manualmente, instale o WSL e o Ansible:

```powershell
wsl --install -d Ubuntu
```

Dentro do Ubuntu/WSL:

```bash
sudo apt update
sudo apt install -y ansible
```

## Como subir a v2

### Windows

```powershell
.\deploy.ps1
```

O script instala Docker dentro das VMs e inicia os serviços automaticamente; não depende de Ansible instalado no Windows/WSL.

### Linux/macOS

```bash
chmod +x deploy.sh
./deploy.sh
```

Após concluir:

- Frontend: http://localhost:8080
- Backend: http://localhost:3001
- Postgres: localhost:5433 (encaminhado para a VM db na porta 5432)

## Execução manual (opcional)

```bash
vagrant up
ansible-playbook -i infra/ansible/inventory.ini infra/ansible/playbook.yml
```

No Windows, o segundo comando exige Ansible no WSL e é opcional, pois `deploy.ps1` já provisiona as VMs pelo Vagrant.

O código Ansible está separado em [infra/ansible](./infra/ansible/README.md).

## Validações

- Health backend: `GET http://localhost:3001/health`
- Frontend: `GET http://localhost:8080` (ou consulte `vagrant port app 80` se houver colisão de portas)
- Postgres: conexão em `localhost:5433` no host (ou `192.168.56.22:5432` na rede privada).
- Playbook pode ser executado mais de uma vez sem duplicar configuração crítica.

## Validação do acesso administrativo na Entrega 2

Após o provisionamento Terraform, conecte-se ao bastion usando a chave pública configurada:

```bash
ssh -i <chave_privada> <usuario>@<ip_publico_bastion>
```

No bastion, confirme o salto para uma VM privada:

```bash
ssh -J <usuario>@<ip_publico_bastion> <usuario>@<ip_privado_vm>
```

A autenticação por senha deve ser recusada:

```bash
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password \
  <usuario>@<ip_publico_bastion>
```

O resultado esperado é `Permission denied (publickey)`.

Na VM privada, confirme a saída pelo NAT:

```bash
curl -s https://ifconfig.me
```

O resultado deve ser o valor de `google_compute_address.nat_ip.address`, obtido com `terraform output nat_ip`.

## Cloud Run na v2

- A v2 não faz deploy em Cloud Run.
- Não há pipeline de CI/CD ativa nesta versão; o deploy é manual/automatizado via Vagrant + Ansible.

## Referências

- [ARQUITETURA.md](./ARQUITETURA.md)
- [docs/VM-MIGRATION.md](./docs/VM-MIGRATION.md)
