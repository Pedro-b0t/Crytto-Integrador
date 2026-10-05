
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
- Exportação: [custos/estimativa.pdf](custos/estimativa.pdf)
- Valores em dólares (US$), região Iowa (`us-central1`), preço sob demanda, sem desconto de conta de faturamento.

**Cenários**

| Cenário | Descrição | Horas | Custo estimado |
|---|---|---|---|
| A: operação contínua | Ambiente ligado 24 h por dia | 730 h/mês | **US$ 49,93 por mês** |
| B: trabalho | Ambiente ligado apenas nas sessões de teste e na apresentação de 23/11 | 80 h (20 sessões de 4 h) | **US$ 9,95** no período |

**Itens de custo (preencher com os valores da calculadora)**

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
