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

## 5.2 Diagrama de arquitetura

Arquivo editável: [diagramas/arquitetura.drawio](diagramas/arquitetura.drawio). Imagem exportada: [diagramas/arquitetura.png](diagramas/arquitetura.png).

![Diagrama de arquitetura](diagramas/arquitetura.png)

**Elementos do diagrama**
- Provedor, região e zona: GCP, `us-central1`, `us-central1-a`.
- Rede virtual: `vpc-grupo-x`, `10.20.0.0/16`.
- Sub-rede pública `pub-a` (`10.20.1.0/24`): `vm-bastion` e `vm-app`, ambas com IP externo estático.
- Sub-rede privada `priv-a` (`10.20.10.0/24`): `vm-db`, sem IP externo.
- Gateway de internet: rota padrão `0.0.0.0/0` para `default-internet-gateway`.
- NAT gerenciado: Cloud Router + Cloud NAT (`nat-grupo-x`), atendendo somente `priv-a`.
- Regras de firewall: `sg-bastion`, `sg-app` e `sg-db` (ver seção 5.5).

**Como a segmentação pública e privada é representada na GCP.** A VPC é global e as sub-redes são regionais; nenhuma sub-rede é pública ou privada por natureza. Neste projeto, `pub-a` é pública porque suas VMs recebem IP externo e regras de firewall que permitem tráfego de entrada. `priv-a` é privada porque suas VMs não têm IP externo e só alcançam a internet pelo Cloud NAT, sem aceitar conexões iniciadas de fora.

**Fluxos numerados**

| Fluxo | Caminho |
|---|---|
| 1. Usuário final acessando a aplicação | Navegador, internet, IP externo da `vm-app` (TCP 80/443), nginx serve o frontend e faz proxy de `/api` para o backend local |
| 2. Administrador acessando via SSH | IP do grupo (`/32`), TCP 22 no IP externo da `vm-bastion`, depois SSH interno para `vm-app` ou `vm-db` |
| 3. Instância privada acessando a internet pelo NAT | `vm-db` (sem IP externo), rota `0.0.0.0/0`, Cloud NAT, internet (atualizações de pacotes e imagens Docker) |
| Interno | `vm-app` acessa `vm-db` na porta TCP 5432 |
