# ADR-002: Saída para a internet da sub-rede privada

No contexto de uma aplicação com backend e banco em sub-rede privada, sem IP público,
diante da necessidade de baixar atualizações e dependências sem ficar acessível pela internet e de manter o custo baixo para o grupo, decidimos usar o NAT gerenciado do provedor (Cloud NAT). Descartamos o NAT em instância (uma VM própria encaminhando o tráfego) e a ausência de saída para a internet, para que as instâncias privadas consigam sair para a internet sem receber conexões de fora e sem que o grupo precise operar, atualizar e proteger uma VM de NAT, aceitando que o NAT gerenciado é cobrado por tempo ligado e por volume de dados processados, mesmo com pouco tráfego (valores na estimativa oficial em docs/custos/), e que a saída de todas as instâncias privadas passa a depender desse único serviço regional.

## Contexto adicional

Na arquitetura do projeto, a aplicação e o banco de dados ficam na sub-rede privada e não possuem IP público, de modo que nada na internet consegue iniciar uma conexão com eles. Ainda assim, essas instâncias precisam acessar a internet para instalar e atualizar pacotes do sistema operacional e baixar as dependências da aplicação. O ADR trata de como oferecer essa saída sem abrir acesso de entrada. O acesso administrativo às instâncias é tratado separadamente no ADR-001.

## Comparação das alternativas

|-------------------------------------------------------------------------|
| Critério               |  NAT gerenciado | NAT em instância | Sem saída |
|-------------------------------------------------------------------------|
| Quem opera             |     provedor    |      grupo       |           |
| Custo                  |                 |                  |    zero   |
| Ponto único de falha   |                 |       VM         |           |
| Esforço de implantação |      Baixo      |    Médio/Alto    |   Nenhum  |
| Segurança              |                 |   Configuração   |   Máxima  |
| Permite atualizar pacotes |    Sim       |       Sim        |    Não    |
|-------------------------------------------------------------------------|

## Por que NAT gerenciado

Escolhemos o NAT gerenciado porque o provedor mantém e atualiza o serviço, enquanto um NAT em instância exigiria que o grupo configurasse, atualizasse e monitorasse uma VM só para essa função. Além disso, ele permite apenas conexões iniciadas de dentro para fora, o que mantém a aplicação e o banco sem IP público e inacessíveis pela internet, e a Entrega 2 também exige esse serviço. 