# Análise de Segurança — Crytto RPG Platform

## S7 — Análise estática de segurança

Foram utilizadas as ferramentas Checkov e Gitleaks para
identificar possíveis vulnerabilidades na infraestrutura
e no histórico do repositório.

### Resultados do Checkov

Comando: `checkov -d infra/`

- Verificações aprovadas: 4
- Verificações com falha: 3
- Verificações ignoradas: 0

### Resultados do Gitleaks

Comando: `gitleaks git .`

- Commits analisados: 20
- Vazamentos detectados: 0

O Gitleaks não identificou vazamentos no histórico analisado.
Entretanto, o Checkov identificou uma possível credencial
exposta em um arquivo de configuração.

### Evidências

- `docs/evidencias/checkov-antes.txt`
- `docs/evidencias/gitleaks-relatorio.json`

## Tabela de achados de segurança

| ID | Problema identificado | Gravidade estimada | Decisão | Justificativa |
|---|---|---|---|---|
| CKV_SECRET_4 | Credencial do PostgreSQL escrita diretamente no all.yml | Alta | Pendente | A senha deve ser removida dos arquivos versionados e protegida adequadamente. |
| CKV2_ANSIBLE_1 | HTTP na verificação local do backend | Baixa | Aceito provisoriamente | A verificação utiliza localhost, sem exposição direta à rede externa. |
| CKV2_ANSIBLE_1 | HTTP na verificação local do frontend | Baixa | Aceito provisoriamente | A verificação utiliza localhost. O acesso externo deve utilizar HTTPS. |

## Melhorias realizadas

Foi alterado o arquivo `infra/ansible/playbook.yml`:

- Permissão do arquivo .env alterada de 0644 para 0600.
- Adicionado `no_log: true` à tarefa que gera o .env.

Essas alterações reduzem a exposição de informações sensíveis,
mas ainda não eliminam a credencial fixa identificada pelo Checkov.

## Cinco ameaças à arquitetura

| Ameaça | Ativo afetado | Controle de segurança | Risco residual |
|---|---|---|---|
| 1. Acesso SSH não autorizado | Máquinas virtuais | Restringir o SSH ao IP autorizado e utilizar autenticação por chave, passando pelo bastion. | Uma chave comprometida ainda pode permitir acesso indevido. |
| 2. Vazamento de senhas do banco | PostgreSQL e dados dos usuários | Armazenar credenciais fora do código, restringir permissões e realizar rotação das senhas expostas. | Uma credencial ainda pode ser comprometida durante sua utilização. |
| 3. Acesso indevido ao banco de dados | PostgreSQL | Manter o banco sem IP público e permitir conexões somente das máquinas autorizadas. | Uma aplicação comprometida pode ser utilizada para acessar o banco. |
| 4. Interceptação de informações | Comunicação entre usuários e aplicação | Utilizar HTTPS para proteger o tráfego externo. | Configurações incorretas ou certificados vencidos podem comprometer a proteção. |
| 5. Exploração de vulnerabilidades na infraestrutura | Servidores e aplicação | Executar verificações de segurança com Checkov e Gitleaks, corrigindo ou justificando os problemas encontrados. | Novas vulnerabilidades podem surgir depois das verificações. |

## Requisitos de segurança — S1 a S8

Esta seção reúne os controles de segurança exigidos
na segunda entrega do projeto.

O andamento de cada requisito será atualizado conforme
as evidências e implementações dos integrantes do grupo.

| Requisito | Controle ou evidência | Situação |
|---|---|---|
| S1 | Desativar autenticação SSH por senha e login direto do root em todas as VMs | Victor | Pendente de verificação |
| S2 | Restringir regras de saída da rede: HTTP/HTTPS, DNS e PostgreSQL apenas entre máquinas autorizadas | Victor | Pendente de verificação |
| S3 | Configurar HTTPS no nginx e redirecionar HTTP para HTTPS | Pedro | Pendente de verificação |
| S4 | Remover a senha fixa do banco do código e utilizar variável Terraform sensível ou Secret Manager | Pedro | Pendente de verificação |
| S5 | Permissões restritas da service account de backup | Pendente de verificação |
| S6 | Criptografia do bucket de backup | Pendente de verificação |
| S7 | Análise com Checkov e Gitleaks | Executado; achados em análise |
| S8 | Autenticação multifator na conta GCP | Pendente de evidência |