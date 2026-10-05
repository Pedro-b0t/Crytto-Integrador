# Documento Técnico de Arquitetura — Crytto RPG Platform

> **Versão:** 2.0  
> **Última atualização:** 14/08/2026  
> **Repositório:** https://github.com/Pedro-b0t/Crytto-Integrador
>
> **Nota da versão v2:** este repositório é executado em duas VMs Ubuntu (app e db) com VirtualBox/Vagrant, Ansible e Docker Compose. As referências históricas a Cloud Run, GitHub Actions e WIF abaixo pertencem à versão original e não fazem parte do fluxo de execução desta v2.

---

## Equipe do Projeto

| Papel | Nome |
|---|---|
| **Product Owner (P.O.)** | Pedro Henrique de Oliveira |
| **Scrum Master** | Victor Nascimento Silva |
| **Desenvolvedor** | Ana Luiza Ripoli Theodorovitz |
| **Desenvolvedor** | João Pedro Foster Ruiz |

### Responsabilidades por papel

- **Product Owner (Pedro Henrique):** priorização do backlog, definição de escopo e critérios de aceite, aprovação de releases.
- **Scrum Master (Victor):** condução das cerimônias, remoção de impedimentos, garantia da aderência ao processo ágil, gestão do repositório e da pipeline de CI/CD.
- **Devs (Ana e João):** implementação do frontend, backend, testes automatizados e integração com serviços em nuvem.

---

## 1. Visão Geral

A **Crytto RPG Platform v2** é uma aplicação web para *streaming*, gerenciamento de sessões e comércio de itens de RPG. A solução é composta por um **frontend React (SPA)**, um **backend Node.js/Express** e um **PostgreSQL**, todos executados em Docker Compose sobre VMs Ubuntu provisionadas por Vagrant e configuradas com Ansible.

---

## 2. Arquitetura da Solução

```
┌─────────────────────────────────────────────────────────────┐
│                        USUÁRIO                              │
│                    (Navegador Web)                          │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTPS
                           ▼
┌─────────────────────────────────────────────────────────────┐
│               GOOGLE CLOUD PLATFORM                         │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Google Cloud Run                        │   │
│  │                                                      │   │
│  │  ┌──────────────────┐    ┌──────────────────────┐   │   │
│  │  │   crytto-frontend │    │   crytto-backend      │   │   │
│  │  │   (nginx + React) │───▶│   (Node.js/Express)   │   │   │
│  │  │   Porta 80        │    │   Porta 3001          │   │   │
│  │  └──────────────────┘    └──────────┬───────────┘   │   │
│  │                                      │               │   │
│  └──────────────────────────────────────┼───────────────┘   │
│                                         │                   │
│  ┌──────────────────────────────────────▼───────────────┐   │
│  │      Postgres Gerenciado (Neon / Supabase)            │   │
│  │      Persistência externa ao Cloud Run                │   │
│  │      Conexão via TLS (sslmode=require)                │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐   │
│  │       Artifact Registry (us-central1)                 │   │
│  │       Repositório Docker: crytto                      │   │
│  │       us-central1-docker.pkg.dev/PROJ/crytto/*        │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐   │
│  │       Workload Identity Federation (WIF)              │   │
│  │       Pool: github-pool  |  Provider: github-provider │   │
│  │       Autenticação GitHub → GCP sem chave JSON        │   │
│  └───────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                           ▲
                           │ OIDC Token
                           │
┌─────────────────────────────────────────────────────────────┐
│                     GITHUB ACTIONS                          │
│  Checkout → Install → Lint → Test → Build → CodeQL → Deploy │
│  (Push automático em main dispara todo o fluxo)             │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Componentes da Aplicação

### 3.1 Frontend (crytto-frontend)
- **Tecnologia:** React 18 + TypeScript + Vite + Tailwind CSS
- **Containerização:** Docker com build multi-stage (Node para build, nginx para servir)
- **Responsabilidade:** Interface do usuário, navegação entre telas, consumo da API REST

### 3.2 Backend (crytto-backend)
- **Tecnologia:** Node.js + Express
- **Banco de dados:** Postgres via driver `pg`, apontando para um serviço gerenciado (Neon ou Supabase). SSL habilitado por padrão em produção.
- **Responsabilidade:** API REST, regras de negócio, persistência de dados.

### 3.3 Banco de Dados (Postgres)
- **Tabelas:** `users`, `characters`, `marketplace_items`, `purchases`, `calendar_events`.
- **Colunas JSONB:** `banner_colors`, `settings`, `stats`, `skills`, `tags`, `images`, `players` — permitem evoluir o modelo sem migrações complexas.
- **Persistência:** externa ao Cloud Run — os containers podem ser recriados/escalados sem perda de dados.

---

## 4. Serviços Utilizados

| Serviço | Uso | Justificativa |
|---|---|---|
| **Google Cloud Run** | Hospedagem dos containers | Serverless, escala automática (incl. scale-to-zero), HTTPS gerenciado, plano gratuito generoso. |
| **Artifact Registry** | Armazenamento das imagens Docker | Sucessor oficial do GCR; integrado nativamente ao Cloud Run e ao IAM do GCP. |
| **Workload Identity Federation** | Autenticação GitHub → GCP | Elimina o uso de chaves JSON. Autenticação via token OIDC do GitHub Actions, validada pelo pool de identidade do GCP. |
| **Neon / Supabase (Postgres)** | Banco de dados gerenciado | Free tier, backups automáticos, persistência independente do Cloud Run, SSL/TLS por padrão. |
| **GitHub Actions (CI/CD)** | Pipeline de build, testes e deploy | Integração nativa com GitHub, sem custo para repositórios públicos, permite automação completa. |
| **CodeQL** | Análise estática de segurança | Detecção automática de vulnerabilidades no código (SAST). Integrado ao GitHub. |

---

## 5. Justificativa Técnica das Escolhas

### Por que Google Cloud Run?
- **Sem servidor para gerenciar:** deploy direto de imagem Docker.
- **Escala para zero:** sem tráfego = sem custo.
- **HTTPS automático:** certificado SSL provisionado automaticamente.
- **Plano gratuito generoso** (2 milhões de requisições/mês grátis).

### Por que Postgres gerenciado (Neon / Supabase)?
- **Persistência real:** o filesystem do Cloud Run é efêmero, então SQLite embarcado não serviria.
- **Free tier suficiente** para um projeto acadêmico com múltiplos usuários.
- **Suporte nativo a JSONB**, ideal para os campos flexíveis do modelo (settings, stats, tags).
- **SSL/TLS ponta a ponta** por padrão.

---

## 6. Fluxo de Comunicação

1. Usuário acessa a URL do **crytto-frontend** via HTTPS.
2. O nginx serve os arquivos estáticos do React.
3. O SPA gera/recupera um `crytto-user-id` anônimo no `localStorage` e chama `POST /api/users` para garantir o registro; depois hidrata perfil, saldo, personagens, itens do marketplace e agenda a partir da API.
4. Toda criação/edição/remoção (personagens, itens, eventos, perfil, saldo) chama a API REST do backend.
5. O backend valida, aplica a lógica de negócio (ex.: transação atômica de compra em `/api/marketplace/:id/purchase`) e persiste no Postgres.

---

## 7. Endpoints da API

| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/users/:id` | Busca dados do usuário |
| POST | `/api/users` | Cria/recupera usuário |
| PUT | `/api/users/:id` | Atualiza perfil |
| PUT | `/api/users/:id/balance` | Atualiza saldo de Crytts |
| GET | `/api/characters/:userId` | Lista personagens do usuário |
| POST | `/api/characters` | Cria personagem |
| PUT | `/api/characters/:id` | Atualiza personagem |
| DELETE | `/api/characters/:id` | Remove personagem |
| GET | `/api/marketplace` | Lista itens do marketplace |
| POST | `/api/marketplace` | Publica item |
| POST | `/api/marketplace/:id/purchase` | Compra item |
| GET | `/api/purchases/:userId` | Lista compras do usuário |
| GET | `/api/calendar/:userId` | Lista eventos do calendário |
| POST | `/api/calendar` | Cria evento |
| PUT | `/api/calendar/:id` | Atualiza evento |
| DELETE | `/api/calendar/:id` | Remove evento |
| GET | `/health` | Health check |

---

## 8. Aspectos de Segurança

- **HTTPS obrigatório:** Cloud Run provisiona SSL automaticamente
- **CORS configurado:** apenas origens autorizadas podem consumir a API
- **Sem dados sensíveis expostos:** nenhuma credencial no código-fonte
- **Variáveis de ambiente:** configurações sensíveis via Cloud Run environment variables
- **Limitação:** autenticação de usuários não implementada nesta versão (melhoria futura)

---

## 9. Limitações da Solução Atual

- Sem autenticação real — identidade do usuário é anexada a um UUID persistido no `localStorage`.
- Upload de arquivos ainda não está implementado (imagens por URL).
- Streams, chat ao vivo e ranking ainda usam dados mock (não fazem parte da persistência avaliada).

---

## 10. CI/CD (Integração Contínua e Deploy Contínuo)

A pipeline de CI/CD é implementada com **GitHub Actions** — arquivo [`.github/workflows/ci-cd.yml`](.github/workflows/ci-cd.yml).

### 10.1 Estratégia de Branches

| Branch | Propósito |
|---|---|
| `main` | Branch de produção. Todo push dispara pipeline completa + deploy. |
| `feature/ci-cd-pipeline` | Configuração da pipeline. |
| `Testes-de-qualidade` | Implementação dos testes automatizados e ESLint. |
| `documentação` | Documentação técnica e sprints. |
| `Backend` / `frontend` | Branches históricas de desenvolvimento por camada. |

O fluxo de trabalho segue **Git Flow simplificado**: features em branches próprias, merge em `main` via PR ou merge direto (para squads pequenos).

### 10.2 Jobs da Pipeline

| # | Job | Ações |
|---|---|---|
| 1 | **Backend – Build, Testes e Lint** | `npm install` → ESLint → Jest (14 testes) → Docker build |
| 2 | **Frontend – Build, Testes e Lint** | `npm install` → ESLint → Vitest (14 testes) → `vite build` → Docker build |
| 3 | **Análise estática (CodeQL)** | Scan de vulnerabilidades JavaScript/TypeScript |
| 4 | **Deploy automatizado no Cloud Run** | Autenticação WIF → push da imagem no Artifact Registry → `gcloud run deploy` (backend e frontend) → validação health check |

### 10.3 Gatilhos

- `push` em `main` → **build + testes + deploy completo**
- `push` em `develop` → build + testes (sem deploy)
- `pull_request` → validação pré-merge (build + testes)
- `workflow_dispatch` → execução manual pelo painel do GitHub

### 10.4 Testes Automatizados

- **Backend (Jest + Supertest):** 14 testes cobrindo endpoints de health check, usuários, marketplace (incluindo transações de compra com mock do pool Postgres) e agenda.
- **Frontend (Vitest + jsdom):** 14 testes cobrindo persistência de personagens (`characterStore`) e navegação (`navigation`).
- **Interrupção automática:** falha em qualquer teste bloqueia o deploy.

### 10.5 Qualidade de Código

- **ESLint** (backend e frontend) — regras de estilo, boas práticas e prevenção de erros comuns.
- **CodeQL** — análise estática de segurança (SAST) executada a cada push.
- **Cobertura:** relatórios gerados por Jest e Vitest a cada execução da pipeline.

### 10.6 Segurança do Deploy

- **Sem chaves JSON:** autenticação via **Workload Identity Federation** — o GitHub Actions se autentica no GCP com um token OIDC de curta duração, validado por um Workload Identity Pool que só aceita tokens do repositório `victorsilv19/Crytto-RPG-Platform`.
- **Secrets no GitHub:**
  - `GCP_WORKLOAD_IDENTITY_PROVIDER` — identificador do provider WIF
  - `GCP_SERVICE_ACCOUNT` — email da service account impersonada
  - `DATABASE_URL` — string de conexão do Postgres
- **Rotação automática:** o token OIDC expira em minutos; não há credencial persistente para vazar.

### 10.7 Documentação complementar

Veja [docs/PIPELINE-CICD.md](./docs/PIPELINE-CICD.md) para detalhes operacionais e [docs/SPRINT-REVIEW.md](./docs/SPRINT-REVIEW.md) / [docs/PO-SM-ATUACAO.md](./docs/PO-SM-ATUACAO.md) para o processo ágil.

---

## 11. Melhorias Futuras

- Implementar **autenticação real** com Firebase Auth ou Google Identity Platform.
- Adicionar **Cloud Storage** para upload de imagens e assets.
- Implementar **deploy canário** (canary deployment) no Cloud Run.
- Migrar `DATABASE_URL` para o **Secret Manager** do GCP (hoje é secret no GitHub).
- Adicionar **Cloud CDN** para melhor performance global.
- Configurar **notificações de falhas** da pipeline (Slack/Discord/e-mail).
- Ampliar a **cobertura de testes** dos componentes React (hoje é focada em `lib/`).
- Adicionar **testes de integração end-to-end** com Playwright.

---

## 12. Como Fazer o Deploy

### 12.1 Pré-requisitos (setup inicial — feito uma única vez)

1. Instalar [Google Cloud CLI (gcloud)](https://cloud.google.com/sdk/docs/install).
2. Instalar [Docker Desktop](https://www.docker.com/products/docker-desktop/).
3. Criar um projeto no [Google Cloud Console](https://console.cloud.google.com).
4. Provisionar um Postgres gerenciado gratuito (**Neon** ou **Supabase**) e copiar a `DATABASE_URL`.
5. Executar os scripts de setup na raiz do repositório (na ordem):
   ```powershell
   .\setup-gcp-wif.ps1              # Cria Service Account + Workload Identity Federation
   .\setup-artifact-registry.ps1    # Cria o repositório Docker
   .\fix-cloudrun-permissions.ps1   # Concede papéis do Cloud Run
   ```
6. Configurar 3 secrets no GitHub (`Settings → Secrets and variables → Actions`):
   - `GCP_WORKLOAD_IDENTITY_PROVIDER`
   - `GCP_SERVICE_ACCOUNT`
   - `DATABASE_URL`

### 12.2 Deploy Automatizado (padrão)

O deploy é **100% automático** ao fazer push na branch `main`:

```bash
git checkout main
git pull
git commit -am "feat: minha alteração"
git push origin main
```

A pipeline GitHub Actions executa build, testes, análise de segurança e deploy no Cloud Run. Acompanhe em:  
https://github.com/victorsilv19/Crytto-RPG-Platform/actions

### 12.3 Deploy Manual (fallback)

```bash
gcloud auth login
gcloud config set project crytto-rpg-2026
gcloud auth configure-docker us-central1-docker.pkg.dev

export DATABASE_URL="postgres://user:pass@host/db?sslmode=require"

# Backend
docker build -t us-central1-docker.pkg.dev/crytto-rpg-2026/crytto/backend:latest ./backend
docker push us-central1-docker.pkg.dev/crytto-rpg-2026/crytto/backend:latest
gcloud run deploy crytto-backend \
  --image us-central1-docker.pkg.dev/crytto-rpg-2026/crytto/backend:latest \
  --region us-central1 --allow-unauthenticated --port 3001 \
  --set-env-vars "DATABASE_URL=$DATABASE_URL"

# Frontend
docker build -t us-central1-docker.pkg.dev/crytto-rpg-2026/crytto/frontend:latest .
docker push us-central1-docker.pkg.dev/crytto-rpg-2026/crytto/frontend:latest
gcloud run deploy crytto-frontend \
  --image us-central1-docker.pkg.dev/crytto-rpg-2026/crytto/frontend:latest \
  --region us-central1 --allow-unauthenticated --port 80
```

### 12.4 Testar localmente antes do deploy
```bash
docker compose up --build
# Acesse http://localhost
```

---

## 13. Histórico de Versões

| Versão | Data | Alterações |
|---|---|---|
| 1.0 | Sprint 1 | Definição inicial da arquitetura, deploy via GCR + chave JSON. |
| 2.0 | 14/08/2026 | Migração para **Artifact Registry**, autenticação via **Workload Identity Federation**, adição de **CodeQL** e **testes automatizados** (Jest + Vitest), consolidação da estratégia de branches, documentação da equipe. |
