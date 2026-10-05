# ADR-003: Localização do banco de dados

No contexto de uma aplicação com dados que precisam sobreviver à recriação da VM de aplicação e de um orçamento limitado,
diante da necessidade de manter o banco fora do alcance da internet,
decidimos executar o PostgreSQL 16 em uma VM (`e2-small`) na sub-rede privada, com disco persistente,
e descartamos o serviço gerenciado Cloud SQL e o banco na mesma VM da aplicação,
para reaproveitar o Docker Compose do projeto, ter controle da instalação e reduzir o custo mensal,
aceitando que o grupo fica responsável por backup, atualizações e recuperação do banco, que há um ponto único de falha sem réplica ou failover automático, e que a perda do disco sem snapshot significa perda de dados.
