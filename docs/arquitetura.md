# Arquitetura em Nuvem: Crytto RPG Platform

Projeto Integrador, Entrega 1. Provedor: Google Cloud Platform (GCP), região `us-central1`, zona `us-central1-a`.

## 5.1 Descrição da aplicação

**Problema que resolve.** Mestres e jogadores de RPG de mesa precisam de um lugar único para transmitir sessões, gerenciar personagens, marcar a agenda e negociar itens. A Crytto RPG Platform reúne essas funções em uma aplicação web.

**Usuários.** Mestres (criadores de conteúdo) e jogadores.

**Funcionalidades principais**
- Cadastro de usuário e perfil, com saldo de moeda virtual (Crytts).
- Criação, edição e remoção de personagens.
- Marketplace de itens, com compra em transação atômica.
- Agenda de eventos e sessões.

**Componentes técnicos**

| Componente | Tecnologia | Exposição |
|---|---|---|
| Frontend | React 18 + TypeScript + Vite, servido por nginx | Pública (HTTP/HTTPS) |
| Backend | Node.js 20 + Express, porta 3001 | Interna, atrás do nginx (`/api`) |
| Banco de dados | PostgreSQL 16 | Privada, sem IP público |

**Atendimento aos requisitos mínimos da seção 3**

| Requisito | Como é atendido |
|---|---|
| Componente acessado pela internet | Frontend web e API, expostos pelo nginx na VM de aplicação |
| Componente que não deve ficar exposto | Banco PostgreSQL, em sub-rede privada e sem IP público |
| Comportamento verificável, com persistência | Cadastro e listagem de personagens, itens e eventos, gravados no PostgreSQL |
| Implantável no prazo da Entrega 2 | Aplicação do próprio grupo, com Dockerfiles e Docker Compose já prontos |

**Requisitos não funcionais assumidos**
- Cerca de 50 usuários simultâneos no pico (uso acadêmico e demonstração).
- Disponibilidade esperada de cerca de 95%, com janelas de manutenção aceitas.
- Esta arquitetura **não oferece alta disponibilidade**: há uma única instância de cada componente, em uma única zona. A alta disponibilidade será proposta na Entrega 2, a partir dos riscos da seção 5.10.
