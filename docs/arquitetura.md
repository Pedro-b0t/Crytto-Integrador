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

## 5.6 Tecnologias

| Camada | Tecnologia | VersÃ£o | Justificativa |
|---|---|---|---|
| Provedor e regiÃ£o | Google Cloud Platform, `us-central1` | - | Custo menor que `southamerica-east1`; a regiÃ£o Ã© elegÃ­vel ao nÃ­vel gratuito de `e2-micro`; o grupo jÃ¡ possui conta com crÃ©ditos. LatÃªncia maior para usuÃ¡rios no Brasil, aceita no contexto acadÃªmico. |
| Sistema operacional | Ubuntu Server LTS | 22.04 | Suporte longo e imagem oficial na GCP |
| Runtime / linguagem | Node.js (container `node:20-alpine`) | 20 LTS | JÃ¡ usado pelo backend e pelo build do frontend |
| Servidor web / proxy | nginx (container) | stable-alpine | Serve o React e faz proxy de `/api` (configuraÃ§Ã£o jÃ¡ existente em `nginx.conf`) |
| Banco de dados | PostgreSQL | 16 | VersÃ£o usada no projeto; suporte a JSONB |
| Infraestrutura como cÃ³digo | Terraform | >= 1.6 | Reprodutibilidade e destruiÃ§Ã£o do ambiente entre sessÃµes |
| Provider do Terraform | `hashicorp/google` | ~> 6.0 | Provider oficial da GCP |
| InstalaÃ§Ã£o da aplicaÃ§Ã£o | Ansible + Docker Compose | Docker Engine 24+ | Playbook e `docker-compose` jÃ¡ existentes no repositÃ³rio |

## 5.7 Dimensionamento das instÃ¢ncias

Carga prevista: cerca de 50 usuÃ¡rios simultÃ¢neos, com trÃ¡fego leve (API REST e arquivos estÃ¡ticos).

| Componente | FamÃ­lia | Tipo | vCPU | MemÃ³ria | Disco (tipo e tamanho) | Sub-rede | Justificativa |
|---|---|---|---|---|---|---|---|
| Bastion | E2 (CPU compartilhada) | `e2-micro` | 2 (0,25 de base) | 1 GiB | `pd-balanced`, 10 GB | `pub-a` | SÃ³ repassa SSH; nÃ£o justifica tamanho maior. ElegÃ­vel ao nÃ­vel gratuito. |
| AplicaÃ§Ã£o | E2 (CPU compartilhada) | `e2-small` | 2 (0,5 de base) | 2 GiB | `pd-balanced`, 20 GB | `pub-a` | Roda nginx e Node.js em containers. Com 1 GiB (`e2-micro`) o build e o consumo do Node ficam apertados. |
| Banco de dados | E2 (CPU compartilhada) | `e2-small` | 2 (0,5 de base) | 2 GiB | `pd-balanced`, 20 GB | `priv-a` | PostgreSQL com poucos dados; 2 GiB comportam o cache bÃ¡sico. |

**Limite de CPU compartilhada.** As famÃ­lias E2 de nÃºcleo compartilhado podem ultrapassar a CPU de base em picos curtos (burst), mas, se o consumo permanecer acima da base, a GCP limita a CPU (throttling). Nesse caso a aplicaÃ§Ã£o continua no ar, porÃ©m mais lenta, com latÃªncia maior nas requisiÃ§Ãµes. Para a carga prevista isso Ã© aceitÃ¡vel; se o uso crescer, o prÃ³ximo tamanho Ã© `e2-medium`.

## 5.8 Registros de DecisÃ£o Arquitetural (ADRs)

| ADR | DecisÃ£o | Arquivo |
|---|---|---|
| ADR-001 | EstratÃ©gia de acesso administrativo: bastion com SSH restrito ao IP do grupo | [adr/001-acesso-administrativo.md](adr/001-acesso-administrativo.md) |
| ADR-002 | SaÃ­da para a internet da sub-rede privada: Cloud NAT gerenciado | [adr/002-saida-internet-subrede-privada.md](adr/002-saida-internet-subrede-privada.md) |
| ADR-003 | LocalizaÃ§Ã£o do banco: PostgreSQL em VM na sub-rede privada | [adr/003-localizacao-banco.md](adr/003-localizacao-banco.md) |

## 5.9 Estimativa de custos

Calculadora oficial: Google Cloud Pricing Calculator.

- CenÃ¡rio A: https://cloud.google.com/products/calculator?hl=pt-BR&dl=CjhDaVF6WWpReU9HUmlNQzB6TldVMkxUUmxNMkl0T1RKbE15MHhZakppTkRFeU5EUXlZelFRQVE9PRAIGiQyQ0M3NzY1OS01Q0VDLTQ0RDktQTc2Qy01MDk1QkM5RTQwNjE
- CenÃ¡rio B: https://cloud.google.com/products/calculator?hl=pt-BR&dl=CjhDaVE1T1Roa05qbGxNUzB5T1ROa0xUUTNOVEl0T1RVME5TMHlabVUzTlRabU1XWm1NREVRQVE9PRAOGiQ5OEM0REQ3Qy1COTY5LTQxMDAtQjQ2NC0yOTgyRDlGRDYxQUQ
- ExportaÃ§Ã£o: [custos/estimativa.pdf](custos/estimativa.pdf)
- Valores em dÃ³lares (US$), regiÃ£o Iowa (`us-central1`), preÃ§o sob demanda, sem desconto de conta de faturamento.

**CenÃ¡rios**

| CenÃ¡rio | DescriÃ§Ã£o | Horas | Custo estimado |
|---|---|---|---|
| A: operaÃ§Ã£o contÃ­nua | Ambiente ligado 24 h por dia | 730 h/mÃªs | **US$ 49,93 por mÃªs** |
| B: trabalho | Ambiente ligado apenas nas sessÃµes de teste e na apresentaÃ§Ã£o de 23/11 | 80 h (20 sessÃµes de 4 h) | **US$ 9,95** no perÃ­odo |

**Itens de custo (preencher com os valores da calculadora)**

| Item | CenÃ¡rio A | CenÃ¡rio B |
|---|---|---|
| Compute Engine: `vm-bastion` (`e2-micro`, disco de boot `pd-balanced` de 10 GiB incluso) | US$ 8,42 | US$ 1,90 |
| Compute Engine: `vm-app` (`e2-small`, disco de boot de 20 GiB incluso) | US$ 15,63 | US$ 3,66 |
| Compute Engine: `vm-db` (`e2-small`, disco de boot de 20 GiB incluso) | US$ 15,63 | US$ 3,66 |
| Cloud NAT (1 VM atendida, 5 GiB no A e 0,5 GiB no B) | US$ 4,90 | US$ 0,74 |
| IPs externos (bastion e app) | US$ 3,65 | US$ 0,00 (valor proporcional a 80 h arredondado para zero pela calculadora; estimado em cerca de US$ 0,40) |
| TrÃ¡fego de saÃ­da para a internet (10 GiB no A e 1 GiB no B) | US$ 1,71 | US$ 0,00 (volume pequeno, arredondado) |
| **Total** | **US$ 49,93** | **US$ 9,95** |

**Item mais caro.** As duas VMs `e2-small` (`vm-app` e `vm-db`), com US$ 15,63 cada no cenÃ¡rio A, e o conjunto das trÃªs VMs representa cerca de 80% do total. O Cloud NAT (US$ 4,90 no A) Ã© o maior custo de rede e cobra mesmo com pouco trÃ¡fego.

**Como reduzi-lo e o que se perde.** Destruir o Cloud NAT e as VMs entre as sessÃµes de teste reduz o custo ao tempo efetivamente usado. Em troca, a aplicaÃ§Ã£o precisa ser reinstalada a cada recriaÃ§Ã£o, o que exige automaÃ§Ã£o (Terraform + Ansible) e acrescenta alguns minutos de espera no inÃ­cio de cada sessÃ£o.

**NÃ­vel gratuito.** Foi considerado, mas nÃ£o aplicado na estimativa: uma `e2-micro` por mÃªs em `us-central1` Ã© elegÃ­vel e poderia zerar o custo de computaÃ§Ã£o da `vm-bastion` (US$ 8,42 no A). As demais instÃ¢ncias, o Cloud NAT e os IPs externos nÃ£o sÃ£o cobertos. Os valores acima sÃ£o, portanto, um teto conservador.

**Origem dos recursos.** A instituiÃ§Ã£o nÃ£o fornece crÃ©ditos. O grupo usa o crÃ©dito promocional de uma conta GCP de um dos integrantes (saldo de R$ 1.509,00, vÃ¡lido atÃ© 27/10/2026). ApÃ³s essa data, o custo Ã© pago pelo grupo, por isso o cenÃ¡rio B considera cobranÃ§a integral para o perÃ­odo posterior a 27/10.

**Plano de controle de custos**
- Alerta de orÃ§amento no Cloud Billing, com notificaÃ§Ãµes em 50%, 90% e 100% do valor definido.
- DestruiÃ§Ã£o do ambiente (`terraform destroy`) ao fim de cada sessÃ£o de teste.
- RÃ³tulos (labels) em todos os recursos, como `projeto=crytto` e `ambiente=entrega2`, para identificar custos.
- EstratÃ©gia diante do trade-off entre custo e esforÃ§o: **recriar o ambiente a cada sessÃ£o**, com reinstalaÃ§Ã£o automatizada pelo Terraform e pelo Ansible. O esforÃ§o de automatizar a instalaÃ§Ã£o Ã© aceito em troca de pagar apenas pelas horas realmente usadas.
