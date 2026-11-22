# Divisão de tarefas: Entrega 2 (Implantação, Segurança, HA e Backup)

Projeto Integrador, Uniamérica Descomplica. Professor: Gildomiro Bairros.

| Marco | Data |
|---|---|
| Entrega no Blackboard (tag `entrega-2` + `.zip` + link do repositório) | **22/11/2026 (domingo), até 23h59** |
| Apresentação (10 min por grupo, todos presentes) | **23/11/2026 (segunda-feira)** |
| `terraform destroy` + evidência | até 24 h após a apresentação |
| Custo real + evidências publicados | até 48 h após a apresentação |

A divisão segue o que cada integrante fez na Entrega 1, para aproveitar o conhecimento acumulado.

## Regras para todos (leiam antes de começar)

- **Projeto GCP: `crytto-integrador`.** Peçam ao Pedro acesso ao projeto e usem `project_id = "crytto-integrador"` no `infra/terraform.tfvars` (o ID antigo `crytto-rpg-2026` não é mais usado).
- **Nada de criar ou alterar recursos pelo console da GCP.** O console serve só para consultar. Recurso criado na mão = requisito não atendido. Exceções: conta, credenciais, alerta de orçamento e bucket de remote state.
- **Nunca commitar** chave privada, `*.tfvars` real, `*.tfstate`, `.terraform/` ou senha. Se acontecer, avisem na hora: a credencial precisa ser revogada e registrada na errata.
- **Custo:** o NAT e os IPs cobram por hora mesmo parados. Subam o ambiente só para testar e rodem `terraform destroy` ao terminar cada sessão.
- Trabalhem em branch própria (`feat/<nome>-<tema>`) e abram PR para a `main`. Antes do PR: `terraform fmt -check` e `terraform validate` sem erros.
- Cada um registra em [errata.md](errata.md) o que mudou na sua parte em relação à Entrega 1 (citando o ADR afetado) e em [../IA.md](../IA.md) o uso de IA.
- **Todos precisam saber explicar todas as partes.** Na defesa técnica o professor sorteia quem responde, inclusive sobre a demonstração de outro integrante, e pode pedir uma alteração no código (por exemplo, trocar o CIDR do SSH). Saibam ler o `terraform plan`: `+` cria, `-` destrói, `~` altera no lugar, `-/+` substitui.

## Pedro Henrique de Oliveira: coordenação, base do Terraform, aplicação e HTTPS

**Fazer primeiro (bloqueia os demais):**
- [ ] Alerta de orçamento no Cloud Billing **antes do primeiro apply** (50%, 90% e 100%), com captura de tela em `docs/evidencias/`. *(manual, no console de faturamento)*
- [ ] **S8:** MFA na conta GCP do grupo, com captura de tela sem dados sensíveis em `docs/evidencias/`. *(manual)*
- [x] Esqueleto em `infra/`: `versions.tf` (Terraform 1.17.2, `google` 6.50.0 e `random` 3.9.1 fixados), `providers.tf` (sem credenciais), `variables.tf` (todas com `type` e `description`), `outputs.tf`, `terraform.tfvars.example`.
- [x] `.gitignore` com `.terraform/`, `*.tfstate`, `*.tfstate.*`, `*.tfvars` (exceto `terraform.tfvars.example`) e chaves; `.terraform.lock.hcl` versionado (hashes para Windows, Linux e macOS). `.gitattributes` força LF nos scripts.

**Depois:**
- [x] `compute.tf`: `vm-bastion`, `vm-app` e `vm-db` com tipo por variável (**R9**), chave SSH pública por variável (**R8**) e IP estático no bastion e na app (**R6**). Shielded VM, chaves de projeto bloqueadas e console serial desligado.
- [x] **R11:** outputs com IP público do bastion, IP público do NAT, IPs privados das VMs e URL da aplicação (mais comandos SSH prontos).
- [x] **R12:** instalação automatizada por startup scripts (`infra/templates/`) com `docker-compose.gcp.yml`; procedimento passo a passo no README. *Falta testar na GCP no primeiro apply.*
- [x] **S3:** HTTPS no nginx (`nginx.https.conf`) com certificado autoassinado e HTTP redirecionando para HTTPS. Testado localmente com Docker.
- [x] **S4:** senha do banco por `TF_VAR_db_password` (`sensitive` + `ephemeral`), gravada no Secret Manager por argumento write-only (fora do state). Nenhuma senha nos arquivos da nuvem.
- [x] **S5 (parte da senha):** service accounts `sa-vm-app` e `sa-vm-db` com acesso apenas ao segredo; bastion sem service account.
- [x] **S6 (discos):** CMEK no Cloud KMS (`infra/kms.tf`) declarada nos três discos de boot.
- [x] **S1 (script):** endurecimento do SSH já incluído no startup script de todas as VMs (`harden_ssh` em `infra/templates/common.sh`).
- [x] README (pré-requisitos, variáveis, apply, instalação, destroy), `docs/errata.md`, `docs/seguranca.md` (S1, S3 a S6), `docs/evidencias/README.md` e IA.md.
- [ ] Primeiro apply real na GCP (depende de `network.tf` e `security.tf` do Victor) e conferência de `terraform plan` sem alterações logo depois.
- [ ] Vídeo de contingência das demonstrações D1 a D6, gravado durante os testes.
- [ ] Tag `entrega-2`, `git archive --format=zip --output=infra-grupo-x.zip entrega-2 infra/` e envio no Blackboard.

**Demonstrações:** D1 (`terraform plan` sem alterações + `terraform output`) e D2 (aplicação por HTTPS executando a funcionalidade verificável).

## Contrato entre os arquivos Terraform (leiam antes de codar)

O código do Pedro referencia recursos que o Victor e o João criam. Usem **exatamente** estes nomes, senão o `terraform validate` falha.

| Quem cria | Recurso Terraform esperado | Usado por |
|---|---|---|
| Victor (`network.tf`) | `google_compute_network.vpc` | firewall |
| Victor (`network.tf`) | `google_compute_subnetwork.pub_a` (`var.public_subnet_cidr`) | `vm-bastion`, `vm-app` |
| Victor (`network.tf`) | `google_compute_subnetwork.priv_a` (`var.private_subnet_cidr`) | `vm-db` |
| Victor (`network.tf`) | `google_compute_address.nat` (IP reservado do Cloud NAT) | output `nat_public_ip` |
| Victor (`security.tf`) | regras por **tags de rede** `bastion`, `app` e `db` (já aplicadas nas VMs) | todas as VMs |

O que o Pedro já entrega para os outros usarem:

| Recurso / variável | Para quê |
|---|---|
| `var.network_name`, `var.vpc_cidr`, `var.public_subnet_cidr`, `var.private_subnet_cidr`, `var.ssh_allowed_cidr` (validação recusa `/0`), `var.region` | Victor: rede e firewall |
| `google_project_service.apis` | Victor e João: colocar em `depends_on` dos recursos de rede e do bucket (habilita compute, KMS, Secret Manager, IAM) |
| `google_service_account.db` | João: conceder a gravação no bucket de backup (S5) |
| `google_kms_crypto_key.cmek` e `data.google_project.this.number` | João: criptografia do bucket (S6), concedendo `roles/cloudkms.cryptoKeyEncrypterDecrypter` a `service-<numero>@gs-project-accounts.iam.gserviceaccount.com` |
| Container `crytto-db` na `vm-db` (PostgreSQL 16, usuário e banco `crytto`) | João: `docker exec crytto-db pg_dump -U crytto crytto` |
| Labels via `default_labels` do provider (`projeto`, `grupo`, `ambiente`, `gerenciado-por`) | Todos: R10 já vale para todo recurso que aceita labels |

Egress (S2, Victor): a `vm-app` precisa de saída TCP 80/443 (apt, Docker Hub, npm, GitHub, APIs do Google) e 5432 para a `vm-db`; a `vm-db` precisa de 80/443 pelo NAT. O metadata server (`169.254.169.254`, usado para tokens e DNS) não é afetado por regras de firewall.

## Victor Nascimento Silva: rede, firewall e acesso administrativo

- [ ] `network.tf`: VPC `10.20.0.0/16` (**R1**), sub-redes `pub-a` e `priv-a` (**R2**), rota para a internet (**R3**), Cloud Router e Cloud NAT com IP reservado, atendendo `priv-a` (**R4**).
- [ ] `security.tf`: regras de firewall da matriz da Entrega 1 (seção 5.5). SSH somente do CIDR informado por variável, **nunca** `0.0.0.0/0` (**R7**).
- [ ] **S2:** regras de saída restritas (HTTP/HTTPS e DNS para pacotes; 5432 somente da app para o banco). Na Entrega 1 a saída era liberada para tudo: registrar na errata.
- [ ] **R5:** `vm-db` em `priv-a`, sem IP público.
- [ ] **R10:** conferir labels nos recursos de rede que aceitam (os `default_labels` do provider já aplicam `projeto`, `grupo`, `ambiente`). VPC, sub-redes e firewall não aceitam labels na GCP: registrar isso em `seguranca.md` ou no README.
- [ ] **S1:** o endurecimento já está no startup script de todas as VMs (`harden_ssh` em `infra/templates/common.sh`). Validar e demonstrar a recusa de senha.
- [ ] Testar o salto pelo bastion (`ssh -J`) e confirmar que `curl -s https://ifconfig.me` na VM privada devolve o IP do NAT.
- [ ] Preencher em `docs/seguranca.md` a descrição dos controles S1 e S2.
- [ ] **Após a apresentação:** `terraform destroy` em até 24 h e evidência em `docs/evidencias/` (sem NAT, IPs, discos, snapshots nem buckets restantes).

**Demonstrações:** D3 (SSH no bastion, acesso à VM privada pelo bastion e recusa de senha: `ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password ...` deve dar `Permission denied (publickey)`) e D4 (saída da VM privada pelo IP do NAT, VM privada sem IP público e SSH restrito ao CIDR autorizado).

## Ana Luiza Ripoli Theodorovitz: alta disponibilidade e análise de segurança

**Parte C (apenas projetada, não implantar):**
- [ ] `docs/diagramas/arquitetura-ha.drawio` e `arquitetura-ha.png`, mantendo `arquitetura.drawio` e `.png` da Entrega 1 para comparação.
- [ ] `docs/alta-disponibilidade.md` cobrindo:
  - [ ] **H1:** duas ou mais zonas, com o plano de endereçamento atualizado (novas sub-redes e CIDRs).
  - [ ] **H2:** load balancer com duas ou mais instâncias (ou grupo de autoescalonamento) e health check definido.
  - [ ] **H3:** estratégia de NAT (um por zona ou compartilhado) e a consequência da escolha.
  - [ ] **H4:** estratégia do banco (Cloud SQL com réplica, réplica própria ou outra solução justificada).
  - [ ] **H5:** estado da aplicação fora da instância (sessões e arquivos enviados).
  - [ ] **H6:** cada um dos 9 riscos da seção 5.10 da Entrega 1, eliminado ou aceito com justificativa.
  - [ ] **H7:** os fluxos numerados da Entrega 1 redesenhados, incluindo o acesso administrativo.
- [ ] Custo mensal da proposta na calculadora oficial, comparado ao cenário A (US$ 49,93) em `docs/custos/`. Indicar os itens que mais pesam e responder se o custo se justifica para o perfil de uso.
- [ ] **ADR-004** (Y-statement): estratégia de alta disponibilidade, incluindo NAT e banco.

**Parte B (análise de segurança):**
- [ ] **S7:** `trivy config infra/` (ou `checkov -d infra/`) e `gitleaks detect --source .` em todo o histórico, com relatórios em `docs/evidencias/`.
- [ ] `docs/seguranca.md`: tabela de achados (todo achado **alto ou crítico** com decisão "Corrigido" ou "Aceito" e justificativa) e **cinco ameaças concretas** à nossa arquitetura (ameaça, ativo, controle aplicado, risco residual). Organizar o documento com S1 a S8; os demais preenchem seus controles.
- [ ] Separar para a demonstração um achado corrigido e um aceito.

**Demonstrações:** D5 (segredos fora do código e relatório com um achado corrigido e um aceito) e D7 (diagrama de HA e análise de custo).

## João Pedro Foster Ruiz: backup e custos

**Política mínima configurada (B6, no Terraform):**
- [ ] `backup.tf`: bucket de backup com criptografia declarada (**S6**), versionamento conforme o plano e regra de ciclo de vida no prefixo `diario/` com expiração em **no máximo 2 dias**.
- [ ] **S5:** service account da `vm-db` com permissão apenas para gravar nesse bucket. Nenhuma chave de acesso gravada na VM.
- [ ] Script de `pg_dump` para `gs://<bucket>/diario/`, agendado ou executado manualmente, com **pelo menos uma cópia existente** no dia da apresentação. Documentar no README.
- [ ] Estimativa de custo da política mínima para o período do trabalho (próxima de zero).

**Plano (`docs/backup.md`):**
- [ ] **B1:** inventário (banco, state do Terraform, configurações) e o que não precisa de backup por ser reproduzível pelo código.
- [ ] **B2:** RPO e RTO justificados pelo uso da aplicação.
- [ ] **B3:** política conservadora GFS (Son, Father, Grandfather) com frequência, promoção, retenção e classe de armazenamento de cada geração.
- [ ] **B4:** onde as cópias ficam (fora da instância, criptografadas, com acesso restrito).
- [ ] **B5:** responsabilidade compartilhada (o que a GCP garante e o que é do grupo).
- [ ] **B6:** política mínima configurada e o que ela **não** protege em relação à GFS.
- [ ] **B7:** custo anual da GFS **mês a mês, de 1 a 12** (custo de um mês só = B7 não atendido), com premissas, valores unitários da calculadora e o parâmetro que mais pesa no custo. Planilha em `docs/custos/`.
- [ ] **ADR-005** (Y-statement): estratégia de backup (parâmetros GFS, mecanismo e local).
- [ ] Atualizar o ADR-003, cuja consequência aceita era não ter backup: status e errata.
- [ ] **Após a apresentação:** custo real do painel de faturamento comparado ao cenário B (US$ 9,95), em `docs/custos/`, em até 48 h.

**Demonstração:** D6 (política mínima: mecanismo, retenção, criptografia e cópia existente no bucket; custo anual da GFS).

## Tarefas compartilhadas

| Tarefa | Responsável |
|---|---|
| Issues abertas pelo professor: responder e fechar referenciando o commit | Quem cuida da área; Pedro acompanha |
| `docs/errata.md` | Cada um registra a sua parte; Pedro consolida |
| `IA.md` | Cada um registra o seu uso; Pedro consolida |
| Ensaio cronometrado da apresentação | Todos |
| Subir o ambiente da tag `entrega-2` antes da aula (NAT ativo) | Pedro e Victor |

## Dependências

```text
Pedro: alerta de orçamento + MFA + esqueleto infra/
   ├── Victor: network.tf / security.tf ──┐
   ├── Pedro:  compute.tf ────────────────┼── primeiro apply completo ── Pedro: app + HTTPS ── João: primeiro dump
   └── João:   backup.tf + service account┘                                                └── Ana: Trivy/Gitleaks
Ana: diagrama e documento de HA (independente, pode começar já)
```

## Cronograma

| Período | O que deve estar pronto |
|---|---|
| 09 a 11/11 | Alerta de orçamento, MFA, esqueleto `infra/`. Todos com Terraform e `gcloud` instalados |
| 12 a 15/11 | `network.tf`, `security.tf`, `compute.tf`, `backup.tf`; rascunho do diagrama de HA |
| 16 a 18/11 | Primeiro apply completo, aplicação com HTTPS, varreduras S7, primeiro dump no bucket |
| 19 a 20/11 | `seguranca.md`, `alta-disponibilidade.md`, `backup.md`, ADR-004, ADR-005, errata, issues, vídeo de contingência |
| 21/11 | Ensaio cronometrado (10 min) e revisão final |
| 22/11 | Tag `entrega-2`, `.zip` com `git archive` e envio no Blackboard |
| 23/11 | Apply antes da aula, `terraform plan` sem alterações e apresentação |

## Roteiro da apresentação (10 min)

| Etapa | Conteúdo | Quem conduz | Tempo |
|---|---|---|---|
| D1 | `terraform plan` sem alterações e `terraform output` | Pedro | 0,5 min |
| D2 | Aplicação por HTTPS e funcionalidade verificável | Pedro | 1 min |
| D3 | SSH no bastion, salto para a VM privada e recusa de senha | Victor | 1,5 min |
| D4 | Saída pelo IP do NAT, VM privada sem IP público, SSH restrito | Victor | 0,5 min |
| D5 | Segredos fora do código; achado corrigido e achado aceito | Ana | 1 min |
| D6 | Política mínima de backup e custo anual da GFS | João | 1,5 min |
| D7 | Diagrama de HA e análise de custo | Ana | 1,5 min |
| Defesa | Perguntas do professor a integrantes sorteados | Todos | 2,5 min |

Ausência de qualquer integrante, ou integrante sem demonstração, custa **20% da nota** do grupo.
