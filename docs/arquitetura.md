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

## 5.3 Plano de endereçamento IP

| Recurso | Nome | CIDR | Zona | Tipo | Finalidade |
|---|---|---|---|---|---|
| Rede virtual | `vpc-grupo-x` | `10.20.0.0/16` | global | modo custom | Rede do projeto |
| Sub-rede | `pub-a` | `10.20.1.0/24` | `us-central1` (VMs em `us-central1-a`) | Pública | Bastion e aplicação |
| Sub-rede | `priv-a` | `10.20.10.0/24` | `us-central1` (VMs em `us-central1-a`) | Privada | Banco de dados |

**IPs internos fixos:** `vm-bastion` `10.20.1.10`, `vm-app` `10.20.1.20`, `vm-db` `10.20.10.10`.

**Justificativa.** Os blocos seguem a faixa privada `10.0.0.0/8` (RFC 1918) e não se sobrepõem. Cada `/24` tem 256 endereços; a GCP reserva 4 em cada sub-rede (rede, gateway, penúltimo e broadcast), restando 252 utilizáveis. O tamanho é muito maior que as 3 VMs atuais, mas permite adicionar instâncias na Entrega 2 (alta disponibilidade) sem recriar a rede. Usar `10.20.0.0/16` na VPC deixa espaço para novas sub-redes (por exemplo, uma segunda zona).

## 5.4 Tabelas de rota

| Sub-rede | Destino | Alvo (next hop) | Observação |
|---|---|---|---|
| `pub-a` | `10.20.1.0/24` | local (rota da sub-rede) | Criada automaticamente |
| `pub-a` | `10.20.10.0/24` | local (rota da sub-rede) | Tráfego interno entre sub-redes |
| `pub-a` | `0.0.0.0/0` | `default-internet-gateway` | VMs com IP externo saem e recebem tráfego direto |
| `priv-a` | `10.20.10.0/24` | local (rota da sub-rede) | Criada automaticamente |
| `priv-a` | `10.20.1.0/24` | local (rota da sub-rede) | Acesso a partir da aplicação e do bastion |
| `priv-a` | `0.0.0.0/0` | `default-internet-gateway`, atendida pelo Cloud NAT | A rota é a mesma da VPC; sem IP externo, a saída só funciona por meio do NAT |

Na GCP, as rotas pertencem à VPC e valem para todas as sub-redes. O que diferencia `priv-a` é a ausência de IP externo nas VMs.

**Sem o NAT.** A `vm-db` perderia a saída para a internet: `apt update`, instalação de pacotes e `docker pull` falhariam, e as atualizações de segurança do banco deixariam de ser aplicadas. A aplicação continuaria funcionando, mas a instalação automatizada da Entrega 2 não seria possível.

## 5.5 Matriz de regras de segurança

Na GCP, o papel de "security group" é feito por regras de firewall da VPC com tags de rede. Os nomes `sg-*` abaixo identificam o grupo lógico de cada papel. O tráfego de entrada não listado é negado por padrão.

| Grupo de segurança | Direção | Protocolo | Porta | Origem/Destino | Justificativa |
|---|---|---|---|---|---|
| `sg-bastion` (tag `bastion`) | Entrada | TCP | 22 | IP público do grupo (`/32`) | Acesso administrativo restrito ao IP do grupo; SSH nunca liberado para `0.0.0.0/0` |
| `sg-app` (tag `app`) | Entrada | TCP | 80, 443 | `0.0.0.0/0` | Acesso público ao frontend e à API |
| `sg-app` | Entrada | TCP | 22 | `sg-bastion` (tag `bastion`) | SSH apenas via bastion |
| `sg-db` (tag `db`) | Entrada | TCP | 5432 | `sg-app` (tag `app`) | Banco acessível somente pela aplicação |
| `sg-db` | Entrada | TCP | 22 | `sg-bastion` (tag `bastion`) | Administração do banco via bastion |
| Todos | Saída | Todos | Todos | `0.0.0.0/0` | Regra padrão de saída; `vm-db` sai pelo Cloud NAT |

**Princípio do menor privilégio.** A porta 3001 do backend não é aberta: o nginx faz o proxy dentro da própria `vm-app`. O banco não tem IP externo e só aceita conexões de origens internas específicas, referenciadas por tag em vez de faixas de IP.

## 5.6 Tecnologias

| Camada | Tecnologia | Versão | Justificativa |
|---|---|---|---|
| Provedor e região | Google Cloud Platform, `us-central1` | - | Custo menor que `southamerica-east1`; a região é elegível ao nível gratuito de `e2-micro`; o grupo já possui conta com créditos. Latência maior para usuários no Brasil, aceita no contexto acadêmico. |
| Sistema operacional | Ubuntu Server LTS | 22.04 | Suporte longo e imagem oficial na GCP |
| Runtime / linguagem | Node.js (container `node:20-alpine`) | 20 LTS | Já usado pelo backend e pelo build do frontend |
| Servidor web / proxy | nginx (container) | stable-alpine | Serve o React e faz proxy de `/api` (configuração já existente em `nginx.conf`) |
| Banco de dados | PostgreSQL | 16 | Versão usada no projeto; suporte a JSONB |
| Infraestrutura como código | Terraform | >= 1.6 | Reprodutibilidade e destruição do ambiente entre sessões |
| Provider do Terraform | `hashicorp/google` | ~> 6.0 | Provider oficial da GCP |
| Instalação da aplicação | Ansible + Docker Compose | Docker Engine 24+ | Playbook e `docker-compose` já existentes no repositório |

## 5.7 Dimensionamento das instâncias

Carga prevista: cerca de 50 usuários simultâneos, com tráfego leve (API REST e arquivos estáticos).

| Componente | Família | Tipo | vCPU | Memória | Disco (tipo e tamanho) | Sub-rede | Justificativa |
|---|---|---|---|---|---|---|---|
| Bastion | E2 (CPU compartilhada) | `e2-micro` | 2 (0,25 de base) | 1 GiB | `pd-balanced`, 10 GB | `pub-a` | Só repassa SSH; não justifica tamanho maior. Elegível ao nível gratuito. |
| Aplicação | E2 (CPU compartilhada) | `e2-small` | 2 (0,5 de base) | 2 GiB | `pd-balanced`, 20 GB | `pub-a` | Roda nginx e Node.js em containers. Com 1 GiB (`e2-micro`) o build e o consumo do Node ficam apertados. |
| Banco de dados | E2 (CPU compartilhada) | `e2-small` | 2 (0,5 de base) | 2 GiB | `pd-balanced`, 20 GB | `priv-a` | PostgreSQL com poucos dados; 2 GiB comportam o cache básico. |

**Limite de CPU compartilhada.** As famílias E2 de núcleo compartilhado podem ultrapassar a CPU de base em picos curtos (burst), mas, se o consumo permanecer acima da base, a GCP limita a CPU (throttling). Nesse caso a aplicação continua no ar, porém mais lenta, com latência maior nas requisições. Para a carga prevista isso é aceitável; se o uso crescer, o próximo tamanho é `e2-medium`.

## 5.8 Registros de Decisão Arquitetural (ADRs)

| ADR | Decisão | Arquivo |
|---|---|---|
| ADR-001 | Estratégia de acesso administrativo: bastion com SSH restrito ao IP do grupo | [adr/001-acesso-administrativo.md](adr/001-acesso-administrativo.md) |
| ADR-002 | Saída para a internet da sub-rede privada: Cloud NAT gerenciado | [adr/002-saida-internet-subrede-privada.md](adr/002-saida-internet-subrede-privada.md) |
| ADR-003 | Localização do banco: PostgreSQL em VM na sub-rede privada | [adr/003-localizacao-banco.md](adr/003-localizacao-banco.md) |

## 5.9 Estimativa de custos

Calculadora oficial: Google Cloud Pricing Calculator.

- Cenário A: https://cloud.google.com/products/calculator?hl=pt-BR&dl=CjhDaVF6WWpReU9HUmlNQzB6TldVMkxUUmxNMkl0T1RKbE15MHhZakppTkRFeU5EUXlZelFRQVE9PRAIGiQyQ0M3NzY1OS01Q0VDLTQ0RDktQTc2Qy01MDk1QkM5RTQwNjE
- Cenário B: https://cloud.google.com/products/calculator?hl=pt-BR&dl=CjhDaVE1T1Roa05qbGxNUzB5T1ROa0xUUTNOVEl0T1RVME5TMHlabVUzTlRabU1XWm1NREVRQVE9PRAOGiQ5OEM0REQ3Qy1COTY5LTQxMDAtQjQ2NC0yOTgyRDlGRDYxQUQ
- Exportação do cenário A: [custos/estimativa-cenario-a.pdf](custos/estimativa-cenario-a.pdf)
- Exportação do cenário B: [custos/estimativa-cenario-b.pdf](custos/estimativa-cenario-b.pdf)
- Valores em dólares (US$), região Iowa (`us-central1`), preço sob demanda, sem desconto de conta de faturamento.

**Cenários**

| Cenário | Descrição | Horas | Custo estimado |
|---|---|---|---|
| A: operação contínua | Ambiente ligado 24 h por dia | 730 h/mês | **US$ 49,93 por mês** |
| B: trabalho | Ambiente ligado apenas nas sessões de teste e na apresentação de 23/11 | 80 h (20 sessões de 4 h) | **US$ 9,95** no período |

**Itens de custo**

| Item | Cenário A | Cenário B |
|---|---|---|
| Compute Engine: `vm-bastion` (`e2-micro`, disco de boot `pd-balanced` de 10 GiB incluso) | US$ 8,42 | US$ 1,90 |
| Compute Engine: `vm-app` (`e2-small`, disco de boot de 20 GiB incluso) | US$ 15,63 | US$ 3,66 |
| Compute Engine: `vm-db` (`e2-small`, disco de boot de 20 GiB incluso) | US$ 15,63 | US$ 3,66 |
| Cloud NAT (1 VM atendida, 5 GiB no A e 0,5 GiB no B) | US$ 4,90 | US$ 0,74 |
| IPs externos (bastion e app) | US$ 3,65 | US$ 0,00 (valor proporcional a 80 h arredondado para zero pela calculadora; estimado em cerca de US$ 0,40) |
| Tráfego de saída para a internet (10 GiB no A e 1 GiB no B) | US$ 1,71 | US$ 0,00 (volume pequeno, arredondado) |
| **Total** | **US$ 49,93** | **US$ 9,95** |

**Item mais caro.** As duas VMs `e2-small` (`vm-app` e `vm-db`), com US$ 15,63 cada no cenário A, e o conjunto das três VMs representa cerca de 80% do total. O Cloud NAT (US$ 4,90 no A) é o maior custo de rede e cobra mesmo com pouco tráfego.

**Como reduzi-lo e o que se perde.** Destruir o Cloud NAT e as VMs entre as sessões de teste reduz o custo ao tempo efetivamente usado. Em troca, a aplicação precisa ser reinstalada a cada recriação, o que exige automação (Terraform + Ansible) e acrescenta alguns minutos de espera no início de cada sessão.

**Nível gratuito.** Foi considerado, mas não aplicado na estimativa: uma `e2-micro` por mês em `us-central1` é elegível e poderia zerar o custo de computação da `vm-bastion` (US$ 8,42 no A). As demais instâncias, o Cloud NAT e os IPs externos não são cobertos. Os valores acima são, portanto, um teto conservador.

**Origem dos recursos.** A instituição não fornece créditos. O grupo usa o crédito promocional de uma conta GCP de um dos integrantes (saldo de R$ 1.509,00, válido até 27/10/2026). Após essa data, o custo é pago pelo grupo, por isso o cenário B considera cobrança integral para o período posterior a 27/10.

**Plano de controle de custos**
- Alerta de orçamento no Cloud Billing, com notificações em 50%, 90% e 100% do valor definido.
- Destruição do ambiente (`terraform destroy`) ao fim de cada sessão de teste.
- Rótulos (labels) em todos os recursos, como `projeto=crytto` e `ambiente=entrega2`, para identificar custos.
- Estratégia diante do trade-off entre custo e esforço: **recriar o ambiente a cada sessão**, com reinstalação automatizada pelo Terraform e pelo Ansible. O esforço de automatizar a instalação é aceito em troca de pagar apenas pelas horas realmente usadas.

## 5.10 Riscos e limitações

| # | Risco ou limitação | Impacto |
|---|---|---|
| 1 | Todos os recursos em uma única zona (`us-central1-a`) | Falha da zona derruba aplicação, banco e bastion ao mesmo tempo |
| 2 | Banco em uma única VM, sem réplica | Falha da VM ou do disco indisponibiliza a aplicação e pode causar perda de dados |
| 3 | Uma única VM de aplicação | Falha ou manutenção da `vm-app` tira o serviço do ar; não há balanceamento |
| 4 | Bastion único e acesso SSH dependente do IP do grupo | Sem o bastion (ou com mudança de IP), não há acesso administrativo até a regra ser atualizada |
| 5 | Cloud NAT único para a sub-rede privada | Falha ou má configuração impede o banco de atualizar pacotes; tem custo fixo por hora |
| 6 | Sem backup automatizado do banco | Perda de dados em caso de erro humano ou falha de disco |
| 7 | CPU compartilhada (`e2-small`) | Lentidão sob carga sustentada |
| 8 | Crédito GCP expira em 27/10/2026 | Custos passam a ser pagos pelo grupo na Entrega 2 |
| 9 | Tráfego público apenas em HTTP até o certificado ser configurado | Dados sem criptografia em trânsito |
