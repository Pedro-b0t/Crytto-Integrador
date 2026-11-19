# Proposta de Alta Disponibilidade — Crytto

## 1. Introdução

Este documento apresenta uma proposta de alta disponibilidade (HA) para a aplicação Crytto, desenvolvida no Projeto Integrador.

Na primeira entrega, a arquitetura utilizava uma única zona da Google Cloud, com apenas uma VM de aplicação e uma VM de banco de dados. Essa estrutura é mais econômica, porém apresenta riscos de indisponibilidade caso algum componente falhe.
Para a segunda entrega, foi elaborada uma arquitetura com duas zonas, balanceamento de carga, banco de dados com alta disponibilidade e maior isolamento da aplicação.

*Esta arquitetura é apenas uma proposta de evolução e não será implantada nesta entrega.*
O diagrama está disponível em `docs/diagramas/arquitetura-ha.drawio` e `docs/diagramas/arquitetura-ha.png`.

## H1 — Distribuição em duas zonas e endereçamento

A proposta utiliza a região `us-central1` da Google Cloud, distribuindo as instâncias de aplicação entre duas zonas:

- `us-central1-a`: primeira VM da aplicação.
- `us-central1-b`: segunda VM da aplicação.

A VPC utilizada é `vpc-grupo-x`, com o bloco de endereços `10.20.0.0/16`.

O plano de endereçamento proposto é:

| Sub-rede | CIDR | Utilização |
|---|---|---|
| `pub-a` | `10.20.1.0/24` | Acesso administrativo pelo bastion |
| `pub-b` | `10.20.2.0/24` | Sub-rede pública adicional, reservada para expansão |
| `priv-a` | `10.20.10.0/24` | `vm-app-a`, IP `10.20.10.20` |
| `priv-b` | `10.20.11.0/24` | `vm-app-b`, IP `10.20.11.20` |

O bastion permanece na sub-rede `pub-a`, com IP privado `10.20.1.10` e IP público estático.
As duas VMs de aplicação não possuem IP público, reduzindo a exposição direta à internet.
Na Google Cloud, as sub-redes são regionais. A distribuição entre zonas é definida pela localização das VMs, e não pela existência de sub-redes exclusivas de cada zona.
Essa distribuição permite que a aplicação continue funcionando caso uma das zonas apresente falha, desde que os demais componentes necessários permaneçam disponíveis.

## H2 — Load Balancer, instâncias e Health Check

A arquitetura propõe um **Load Balancer HTTPS externo**, responsável por receber as conexões dos usuários e distribuir o tráfego entre duas instâncias:

- `vm-app-a`: VM `e2-small`, na zona `us-central1-a`.
- `vm-app-b`: VM `e2-small`, na zona `us-central1-b`.

O Load Balancer utiliza um endereço IP público estático e recebe conexões HTTPS na porta 443.
As aplicações continuam executando o frontend React servido pelo nginx e o backend Node.js.
Para verificar a disponibilidade das instâncias, será utilizado um **health check HTTP** no endpoint `/health`, já existente no backend.
O endpoint verifica a comunicação com o PostgreSQL e retorna uma resposta de sucesso quando o banco está acessível. Em caso de falha, retorna HTTP 503.
Na implantação proposta, o balanceador deverá encaminhar tráfego somente às instâncias consideradas saudáveis. Se uma VM falhar, a outra poderá continuar atendendo às solicitações.
O firewall deverá permitir o tráfego necessário do balanceador e dos verificadores de integridade, sem liberar acesso público direto às VMs.

## H3 — Estratégia de NAT

A proposta mantém o Cloud Router e o Cloud NAT, utilizando o recurso `nat-grupo-x` para permitir a saída das VMs privadas para a internet.
O NAT atenderá às sub-redes `priv-a` e `priv-b`.
A escolha é por um **Cloud NAT compartilhado na região**, em vez de criar um recurso separado para cada zona.
Essa estratégia simplifica a administração e evita duplicar configurações desnecessariamente. O Cloud NAT é um serviço gerenciado regional, e não uma VM instalada em uma zona específica.
Como consequência, problemas de configuração, regras de saída incorretas ou indisponibilidade regional ainda podem afetar as duas aplicações. Também haverá custos de processamento e tráfego associados ao serviço.
As VMs privadas poderão utilizar essa saída para atualizações de pacotes e outras conexões externas necessárias, sem receber IPs públicos.

## H4 — Alta disponibilidade do banco de dados

Na primeira entrega, o PostgreSQL 16 era executado em uma única VM privada, sem réplica.
Para melhorar a disponibilidade, a proposta substitui essa VM por um **Cloud SQL for PostgreSQL com configuração de alta disponibilidade regional**.
O serviço mantém uma instância primária e uma instância de espera em zonas diferentes da mesma região.
Em caso de falha da instância primária, o Cloud SQL pode realizar o failover para a instância de espera, reduzindo a necessidade de intervenção manual.
A conexão das VMs de aplicação com o banco será realizada por IP privado, utilizando a porta TCP 5432.
Também serão habilitados backups automáticos para permitir a recuperação de dados.
A alta disponibilidade reduz o tempo de indisponibilidade causado por falhas de infraestrutura, mas não substitui os backups. Exclusões acidentais ou alterações incorretas nos dados ainda exigem mecanismos de recuperação.

## H5 — Estado da aplicação fora das instâncias

Para que duas VMs possam atender aos mesmos usuários, é importante que os dados necessários ao funcionamento da aplicação não dependam do armazenamento local de uma única instância.

Ao analisar o código atual do Crytto, identificamos que:

- Os dados persistentes de usuários, personagens, compras e eventos são armazenados no PostgreSQL.
- A autenticação e a sessão atuais são mantidas no `localStorage` do navegador, não na memória do backend.
- O backend trabalha principalmente com requisições HTTP e dados armazenados no banco.
- Não foi identificado um mecanismo de upload que armazene arquivos diretamente nos discos das VMs.

Assim, a proposta não exige Redis para compartilhar sessões entre as VMs, nem Cloud Storage para substituir um armazenamento local de uploads que não existe no backend atual.

As imagens são representadas principalmente por URLs e referências nos dados da aplicação.
**Limitação de segurança:** a autenticação atual utiliza dados armazenados no navegador e não oferece a segurança esperada de uma aplicação em produção. Como melhoria futura, recomenda-se implementar autenticação validada pelo servidor, com gerenciamento seguro de credenciais e sessões.
Se o sistema passar a aceitar uploads de arquivos, esses arquivos deverão ser armazenados em um serviço compartilhado, como o Cloud Storage, e não no disco de uma VM específica.

## H6 — Tratamento dos nove riscos da primeira entrega

A seção 5.10 da primeira entrega identificou nove riscos e limitações. A tabela apresenta como cada um será tratado na arquitetura proposta.

| Nº | Risco identificado | Decisão e justificativa |
|---|---|---|
| 1 | Recursos em uma única zona | **Mitigado.** As aplicações passam a funcionar em duas zonas, e o Cloud SQL utiliza alta disponibilidade regional. O bastion continua único. |
| 2 | Banco em uma única VM, sem réplica | **Mitigado.** O Cloud SQL HA oferece uma instância de espera e failover gerenciado. |
| 3 | Uma única VM de aplicação | **Mitigado.** Duas VMs ficam atrás do Load Balancer com verificações de integridade. |
| 4 | Bastion único e SSH dependente do IP do grupo | **Aceito parcialmente.** O bastion permanece único por simplicidade e custo. Uma falha poderá interromper temporariamente o acesso administrativo, sem necessariamente derrubar a aplicação. |
| 5 | Cloud NAT único | **Aceito com justificativa.** O Cloud NAT é regional e gerenciado. Mantemos uma configuração compartilhada, mas erros de configuração e problemas regionais continuam sendo riscos. |
| 6 | Ausência de backup automatizado do banco | **Mitigado na proposta.** O Cloud SQL terá backups automáticos. A recuperação dependerá da política de retenção e dos testes de restauração. |
| 7 | CPU compartilhada das VMs `e2-small` | **Aceito.** O projeto possui perfil acadêmico e demanda moderada. O balanceamento distribui as requisições, mas não elimina possíveis limitações de desempenho. |
| 8 | Expiração dos créditos da GCP | **Aceito como limitação financeira.** A arquitetura HA é apenas projetada. Sua implantação dependeria de orçamento e acompanhamento dos custos. |
| 9 | Tráfego público em HTTP sem certificado | **Mitigado na proposta.** O Load Balancer receberá as conexões públicas por HTTPS, utilizando certificado TLS. |

A arquitetura proposta reduz principalmente os riscos de indisponibilidade da aplicação e do banco de dados.
Entretanto, ainda existem limitações, como o bastion único, possíveis falhas regionais, custos mais elevados e a necessidade de melhorar a autenticação da aplicação.

## H7 — Fluxos de comunicação

Os fluxos da primeira entrega foram adaptados para a nova arquitetura.

### Fluxo 1 — Usuário acessando a aplicação

1. O usuário acessa a aplicação pela internet.
2. A conexão HTTPS, na porta 443, chega ao Load Balancer.
3. O balanceador verifica quais instâncias estão saudáveis.
4. A requisição é encaminhada para `vm-app-a` ou `vm-app-b`.
5. O nginx disponibiliza o frontend e encaminha as requisições `/api` para o backend Node.js.
6. Quando necessário, o backend consulta o Cloud SQL PostgreSQL pela conexão privada.

O usuário não acessa diretamente o IP de nenhuma VM de aplicação.

### Fluxo 2 — Acesso administrativo por SSH

1. O administrador utiliza o endereço IP autorizado do grupo.
2. A conexão SSH, na porta TCP 22, chega ao `vm-bastion`, que possui IP público.
3. A partir do bastion, o administrador pode acessar `vm-app-a` ou `vm-app-b` pelos IPs privados.
4. O acesso deve utilizar chaves SSH e regras de firewall restritas.

O Cloud SQL é um serviço gerenciado e não recebe acesso SSH como uma VM comum.

### Fluxo 3 — Saída das instâncias privadas para a internet

1. Uma VM privada precisa acessar a internet, por exemplo, para atualizar pacotes.
2. O tráfego utiliza a rota de saída configurada na VPC.
3. O Cloud NAT permite a conexão de saída utilizando seu endereço externo.
4. A resposta retorna à VM que iniciou a comunicação.

Esse mecanismo não permite que usuários da internet iniciem conexões diretamente com as VMs privadas.

### Fluxo interno — Aplicação e banco de dados

As instâncias `vm-app-a` e `vm-app-b` acessam o Cloud SQL PostgreSQL por conexão privada, utilizando TCP 5432.
O acesso ao banco deve ser limitado aos componentes autorizados.

## 8. Considerações finais

A proposta de alta disponibilidade do Crytto melhora a continuidade do serviço ao distribuir a aplicação entre duas zonas e utilizar serviços gerenciados para balanceamento de carga e banco de dados.
As principais melhorias são a redução de pontos únicos de falha, o isolamento das VMs de aplicação e a possibilidade de recuperação automática diante de determinadas falhas.
Por outro lado, essa estrutura possui custo superior ao cenário original e exige maior atenção à configuração e ao monitoramento.
Considerando que o Crytto é um projeto acadêmico, a implantação completa de alta disponibilidade não é necessária para as demonstrações atuais. A proposta serve para mostrar como o sistema poderia evoluir caso tivesse maior quantidade de usuários e exigências de disponibilidade.
A comparação financeira detalhada será apresentada separadamente na estimativa de custos da arquitetura HA.