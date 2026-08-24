# Relatório de Andamento do Projeto — Crytto RPG Platform

> **Data do relatório:** 14/08/2026
> **Versão:** 2.0 (atualização do relatório de 07/08/2026)
> **Repositório:** https://github.com/Pedro-b0t/Crytto-Integrador
>
> **Nota da versão v2:** o fluxo atual desta entrega usa VirtualBox/Vagrant, Ansible e Docker Compose em duas VMs. Os registros de Cloud Run e CI/CD abaixo são histórico da versão original.

---

## 1. Identificação da equipe

| Integrante | Papel |
|---|---|
| Pedro Henrique de Oliveira | Product Owner |
| Victor Nascimento Silva | Scrum Master |
| Felipe Jacinto Camilo | Desenvolvedor |
| Pablo Alberto Centurion Leguizamon Junior | Desenvolvedor |

---

## 2. Funcionalidades concluídas

As funcionalidades abaixo estão implementadas de ponta a ponta — interface, API REST e persistência real no Postgres gerenciado (Neon/Supabase):

- **Identificação de usuário:** registro/recuperação de perfil por UUID anônimo, sem necessidade de senha.
- **Gerenciamento de personagens:** criação, edição e remoção de fichas de personagem (`CharacterManager`, `CharacterSheet`).
- **Marketplace:** listagem e compra de itens, com transação atômica de saldo (`EnhancedMarketplace`, `CryttsShop`).
- **Agenda de sessões:** criação, edição e remoção de eventos de calendário (`CalendarAgenda`).
- **Customização de perfil:** edição de perfil, cores de banner e tema visual (`ProfileCustomizer`, `ThemeCustomizer`).
- **Deploy em nuvem:** frontend e backend publicados como serviços independentes no **Google Cloud Run**, com imagens Docker armazenadas no **Artifact Registry** (`us-central1-docker.pkg.dev/crytto-rpg-2026/crytto/*`) — substituindo o antigo Container Registry (GCR), descontinuado pelo Google.

### 🆕 Novidades desde o relatório anterior (07/08 → 14/08)

- **Pipeline de CI/CD concluída (entrega final do projeto):** implementada em **GitHub Actions** com 4 jobs — `backend-build`, `frontend-build`, `code-quality` (CodeQL) e `deploy`. Push em `main` dispara automaticamente build, testes, análise de segurança e deploy no Cloud Run.
- **Testes automatizados:** 14 testes no backend (Jest + Supertest) e 14 testes no frontend (Vitest + jsdom), todos passando na pipeline.
- **Análise de segurança automatizada:** integração com **CodeQL** rodando a cada push.
- **Autenticação segura no GCP via Workload Identity Federation (WIF):** substituição da abordagem de chave JSON de Service Account (bloqueada pela org policy `iam.disableServiceAccountKeyCreation`) por OIDC token, seguindo as boas práticas mais recentes de segurança.
- **Documentação técnica atualizada:** `ARQUITETURA.md` v2.0 com diagrama atualizado, seção de equipe, WIF, Artifact Registry, pipeline e histórico de versões.

---

## 3. Funcionalidades em desenvolvimento

- **Autenticação real:** hoje o usuário é identificado apenas por um UUID anônimo salvo no `localStorage`; ainda não há login com senha ou provedor externo.
- **Chat ao vivo:** interface já existe (`ChatArea`), mas ainda funciona com dados mock, sem persistência ou tempo real.
- **Streams e replay de sessões:** componentes de player já construídos (`ReplayPlayer`, `AudioPlayer`), também operando com dados mock.
- **Sistema de conquistas/ranking:** interface pronta (`Achievements`, `CreatorRanking`), aguardando lógica de negócio e persistência.

---

## 4. Dificuldades encontradas

### Já resolvidas nesta semana

- **Deploy automatizado no Cloud Run com GitHub Actions:** a criação de chave JSON de Service Account estava bloqueada pela política organizacional da conta GCP. Foi necessário migrar para **Workload Identity Federation**, criar o Pool e Provider OIDC, configurar o binding entre o repositório GitHub e a Service Account, e ajustar o workflow para usar `google-github-actions/auth@v2` com `workload_identity_provider`.
- **Descontinuação do Container Registry (gcr.io):** o Google bloqueou pushes para o GCR (`artifactregistry.repositories.uploadArtifacts denied`). Foi criado um repositório no **Artifact Registry** (`us-central1-docker.pkg.dev/crytto-rpg-2026/crytto`) e os workflows foram atualizados.
- **Permissões da Service Account:** foi necessário conceder manualmente `roles/run.admin`, `roles/iam.serviceAccountUser` e permissão de uso da Compute Service Account para o deploy funcionar de ponta a ponta.
- **Testes de compra do Marketplace falhando (500):** faltavam mocks para as queries `BEGIN`/`ROLLBACK`/`COMMIT` da transação atômica. Corrigido — 14/14 testes passando.
- **Vitest tentando rodar testes do Jest:** foi necessário excluir `backend/**` do escopo do Vitest no `vite.config.ts`.

### Em andamento

- Nenhum bloqueio ativo no momento. A pipeline de CI/CD foi validada com **três execuções automáticas consecutivas em `main`, todas bem-sucedidas** (ver seção 6).

---

## 5. Próximos passos da equipe

Com a **pipeline de CI/CD entregue**, o foco agora se move para amadurecer as funcionalidades sociais e a segurança da aplicação:

1. **Implementar autenticação real** (Firebase Auth ou Google Identity Platform), substituindo o UUID anônimo do `localStorage`.
2. **Sair dos dados mock** em chat, streams e ranking, ligando-os à persistência real no Postgres.
3. **Adicionar Cloud Storage** para upload de imagens/assets (avatares, capas de sessão, arquivos de áudio).
4. **Migrar segredos** (`DATABASE_URL`, credenciais externas) para o **Secret Manager** do GCP, removendo-os de variáveis de ambiente diretas.
5. **Ampliar cobertura de testes** — hoje a suíte cobre os endpoints principais; a meta é chegar a >80% de cobertura em `src/lib` e nos módulos críticos do backend (marketplace, autenticação).
6. **Monitoramento e observabilidade:** habilitar Cloud Logging estruturado, métricas do Cloud Run e alertas básicos (erro 5xx, latência, uso de CPU).

---

## 6. Métricas atuais do projeto

| Indicador | Valor |
|---|---|
| Branches integradas ao `main` nesta semana | `feature/ci-cd-pipeline`, `Testes-de-qualidade`, `documentação` |
| Testes automatizados (backend) | 14/14 passando |
| Testes automatizados (frontend) | 14/14 passando |
| Jobs da pipeline CI/CD | 4 (`backend-build`, `frontend-build`, `code-quality`, `deploy`) |
| Serviços em produção no Cloud Run | 2 (`crytto-frontend`, `crytto-backend`) |
| Autenticação GitHub → GCP | Workload Identity Federation (sem chave JSON) |
| Registro de imagens Docker | Artifact Registry (`us-central1`) |
| Banco de dados | Postgres gerenciado (Neon/Supabase) com TLS |

---

## 7. Validação da pipeline de CI/CD

A entrega final do projeto — pipeline de CI/CD automatizada com deploy no Cloud Run — foi validada em produção. As três últimas execuções do workflow `CI/CD Pipeline` em `main`, disparadas automaticamente por `push`, terminaram com sucesso:

| # | Commit | Descrição | Status | Duração |
|---|---|---|---|---|
| **#12** | `d459afb` | `ci: retry deploy apos ajuste de permissoes Cloud Run` | ✅ Sucesso | 4m 29s |
| **#11** | `87760d5` | `docs: atualiza arquitetura com equipe, WIF, Artifact Registry e CI/CD` | ✅ Sucesso | 5m 7s |
| **#10** | `d459afb` | `ci: retry deploy apos ajuste de permissoes Cloud Run` | ✅ Sucesso | 4m 33s |

**Conclusões da validação:**

- ✅ **Deploy 100% automático** disparado por push em `main`, sem intervenção manual — cumpre o requisito 1.5 da entrega.
- ✅ **Autenticação via Workload Identity Federation** funcionando de ponta a ponta (nenhuma chave JSON armazenada em segredo).
- ✅ **Publicação no Artifact Registry** confirmada (imagens `backend` e `frontend` versionadas por SHA do commit).
- ✅ **Deploy dos dois serviços no Cloud Run** (`crytto-backend` e `crytto-frontend`) concluído em cada run.
- ✅ **Tempo médio de pipeline: ~4,5 minutos**, dentro do aceitável para CI/CD de projeto deste porte.

Com isso, a pipeline sai do estado "em observação" e passa a ser considerada **estável e em produção**.

---

_Documento gerado localmente pela equipe para acompanhamento interno. Para detalhes técnicos e diagramas completos, consulte [`ARQUITETURA.md`](ARQUITETURA.md)._
