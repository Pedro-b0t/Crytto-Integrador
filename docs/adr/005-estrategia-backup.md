# ADR-005: Estratégia de backup

No contexto de um banco PostgreSQL em VM (ADR-003), em que o grupo é responsável pelo backup e a perda do disco significa perda de dados,
diante da necessidade de recuperar os dados após exclusão acidental, corrupção ou ataque, com RPO de 24 horas e RTO de 2 horas e custo próximo de zero durante o trabalho,
decidimos fazer dump lógico diário (`pg_dump` compactado) gravado pela própria `vm-db` em um bucket do Cloud Storage em `us-central1`, criptografado com a chave CMEK do projeto, com a service account da VM limitada a `roles/storage.objectCreator`, e recomendar para produção a política GFS com Son diário retido por 7 dias em Standard, Father semanal (cópia de domingo) retido por 35 dias em Nearline e Grandfather mensal (último domingo do mês) retido por 365 dias em Coldline, configurando nesta entrega apenas a geração Son com expiração de 1 dia,
e descartamos o snapshot agendado do disco da `vm-db`, o Backup and DR Service e a migração para Cloud SQL com backup automático,
para obter cópias consistentes do ponto de vista do banco, independentes da VM e do disco, que um invasor na `vm-db` não consegue ler nem apagar, a um custo anual estimado de US$ 1,51 na política GFS,
aceitando que o bucket é regional e não protege contra falha da região, que a política mínima não permite desfazer um erro descoberto depois de 2 dias, que uma conta com papel de dono no projeto ainda consegue apagar o bucket, que o state do Terraform continua fora da política, e que a restauração não foi testada.
