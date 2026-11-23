# Backup (Parte D)

Plano de backup da Crytto RPG Platform. Há duas políticas, com papéis diferentes:

| Política | Papel | Onde aparece |
|---|---|---|
| Conservadora (GFS) | O que o grupo recomendaria para operar a aplicação de verdade | Apenas neste plano, com custo para 12 meses (B3, B7) |
| Mínima | Exercitar o mecanismo com custo próximo de zero | Configurada por Terraform ([infra/backup.tf](../infra/backup.tf)) e demonstrada na D6 (B6) |

Decisão registrada no [ADR-005](adr/005-estrategia-backup.md). Alta disponibilidade não substitui backup: se uma tabela for apagada, uma réplica apaga a mesma tabela segundos depois, e o Terraform recria a infraestrutura, mas não os dados.

## B1. Inventário

| Ativo | Precisa de backup? | Justificativa |
|---|---|---|
| Banco PostgreSQL (`crytto` na `vm-db`): usuários, saldo de Crytts, personagens, itens, compras e agenda | **Sim** | Único dado de negócio; não é reproduzível pelo código. A perda do disco da `vm-db` apaga tudo (risco 6 da Entrega 1) |
| State do Terraform (`infra/terraform.tfstate`) | **Sim** | Sem ele o Terraform não sabe quais recursos gerencia (destroy e alterações ficam manuais). Hoje fica no computador de quem executa o apply; o recomendado é um backend remoto em bucket com versionamento (exceção permitida pelo enunciado) |
| Senha do banco (Secret Manager) | **Sim, pelo provedor** | O Secret Manager mantém as versões do segredo. A senha também precisa estar guardada fora da nuvem (gerenciador de senhas do grupo), porque um dump só é restaurável com acesso ao banco |
| Arquivos enviados por usuários | Não existem | A aplicação não tem upload: imagens são URLs gravadas no banco (ver H5 em [alta-disponibilidade.md](alta-disponibilidade.md)) |
| VMs, discos de sistema, rede, firewall, NAT, IAM, chave KMS | **Não** | Reproduzíveis pelo código Terraform ([infra/](../infra/)) |
| Aplicação (frontend, backend) e configuração (nginx, Compose, startup scripts) | **Não** | Versionadas no Git e reinstaladas automaticamente pelos startup scripts |
| Certificado TLS autoassinado | **Não** | Gerado novamente na criação da `vm-app` |
| Chave privada SSH do grupo | Fora do escopo da nuvem | Fica com os integrantes; perdida, basta gerar outra e trocar `ssh_public_key_path` |

## B2. RPO e RTO

| Meta | Valor | Justificativa |
|---|---|---|
| **RPO** (perda máxima de dados) | **24 horas** | Perfil da seção 5.1 da Entrega 1: cerca de 50 usuários, uso acadêmico, poucas escritas por dia (cadastros, compras de itens, agenda). Perder um dia de alterações é aceitável; um RPO menor exigiria backup contínuo (WAL/PITR), com custo e complexidade incompatíveis |
| **RTO** (tempo para voltar) | **2 horas** | A disponibilidade esperada é de 95% (até ~36 h de indisponibilidade por mês). Recriar o ambiente com Terraform leva ~15 min; baixar e restaurar o dump leva minutos para o volume previsto; o restante é margem para diagnóstico |

O backup diário (geração Son) atende o RPO de 24 h.

## B3. Política conservadora (GFS)

Mecanismo para o banco: **dump lógico** (`pg_dump`, compactado com gzip) gravado em **object storage** (Cloud Storage). O dump é consistente do ponto de vista do banco, porque o `pg_dump` lê um snapshot de uma única transação; por isso foi preferido ao snapshot do disco, que seria apenas *crash-consistent*.

| Geração | Frequência | Momento da promoção | Retenção | Classe de armazenamento | Prefixo |
|---|---|---|---|---|---|
| **Son** (filho) | Diária, 06:00 UTC (03:00 de Brasília, fora do horário de uso) | Cada dump novo entra em `diario/` | **7 dias** (7 cópias) | Standard | `diario/` |
| **Father** (pai) | Semanal | A cópia diária de **domingo** é copiada (cópia no servidor, sem download) para `semanal/` | **35 dias** (5 cópias) | Nearline | `semanal/` |
| **Grandfather** (avô) | Mensal | A cópia semanal mais recente do **último domingo do mês** é copiada para `mensal/` | **365 dias** (12 cópias) | Coldline | `mensal/` |

Implementação: uma regra de ciclo de vida por prefixo (`Delete` com `age` = 7, 35 e 365) e a promoção feita por um job agendado na própria `vm-db` ou por um Cloud Scheduler. A retenção da geração semanal foi fixada em 35 dias, e não 28, para respeitar a duração mínima de cobrança de 30 dias da classe Nearline (apagar antes gera cobrança do restante). A Coldline tem mínimo de 90 dias, muito abaixo dos 365 dias da geração mensal.

Mecanismo por ativo:

| Ativo | Mecanismo |
|---|---|
| Banco PostgreSQL | Dump lógico diário em object storage, com as três gerações acima |
| State do Terraform | Backend remoto `gcs` com versionamento de objetos (cada `apply` gera uma versão) |
| Senha do banco | Versões do Secret Manager + cópia no gerenciador de senhas do grupo |

## B4. Armazenamento

- **Fora da instância:** bucket do Cloud Storage, separado da `vm-db`. A perda ou o comprometimento da VM não leva os backups junto.
- **Localização:** bucket regional em `us-central1`, com os dados replicados pelo provedor em mais de uma zona. A política conservadora recomenda bucket **dual-region** (ou cópia para outra região) para sobreviver a uma falha regional; a política mínima usa regional para manter o custo perto de zero.
- **Criptografia (S6):** o bucket usa a mesma chave CMEK do Cloud KMS dos discos (`encryption.default_kms_key_name`), declarada no código. Os objetos gravados herdam a chave (conferido com `gcloud storage objects describe`).
- **Acesso restrito (S5):** a service account `sa-vm-db` tem apenas `roles/storage.objectCreator` **no bucket**. Ela cria objetos novos, mas recebe 403 ao listar, ler, sobrescrever ou apagar (testado na `vm-db`). Um invasor que tome a VM do banco não consegue apagar os backups. O bucket tem acesso público bloqueado (`public_access_prevention = "enforced"`) e acesso uniforme por IAM.

## B5. Responsabilidade compartilhada

| Ativo | O provedor (Google Cloud) garante | Responsabilidade do grupo |
|---|---|---|
| Objetos no Cloud Storage | Durabilidade (11 noves), replicação entre zonas, criptografia em repouso e execução das regras de ciclo de vida | Gerar os dumps, definir retenção e classes, controlar quem pode apagar, testar a restauração |
| Disco da `vm-db` | Durabilidade do disco persistente e criptografia | O disco não é backup: se a tabela for apagada ou corrompida, o disco guarda o erro. Fazer o dump |
| PostgreSQL (em VM, não gerenciado, ADR-003) | Nada além da VM | Instalação, atualização, consistência e backup do banco |
| Chave KMS | Disponibilidade e rotação automática | Não destruir a chave enquanto houver backups cifrados com ela |
| Secret Manager | Armazenamento e versões do segredo | Guardar a senha fora da nuvem e rotacioná-la |
| State do Terraform | Nada (está fora da nuvem hoje) | Guardar e versionar o state |

## B6. Política mínima configurada

Apenas a geração **Son**, com retenção curta, aplicada ao banco (opção A da seção 6.3: dump lógico em object storage).

| Requisito | Como foi atendido | Onde |
|---|---|---|
| Configuração por código | Bucket, regra de ciclo de vida, criptografia, bloqueio de acesso público e permissão da VM criados por Terraform. Agenda (systemd timer) e script de dump instalados pelo startup script da `vm-db`, também gerado pelo Terraform | [infra/backup.tf](../infra/backup.tf), [infra/templates/db.sh.tftpl](../infra/templates/db.sh.tftpl), [infra/templates/backup.sh](../infra/templates/backup.sh) |
| Retenção | Objetos em `diario/` são apagados com **1 dia** de idade (`backup_retention_days`, validado entre 1 e 2). Versionamento e *soft delete* desativados, para que nenhuma cópia fique retida além do prazo | `lifecycle_rule` em `infra/backup.tf` |
| Criptografia | CMEK `cmek-crytto` como chave padrão do bucket | `encryption` em `infra/backup.tf` |
| Identidade da instância | A `vm-db` grava com a própria service account, token do metadata server, sem chave no disco. Permissão restrita a criar objetos naquele bucket | `google_storage_bucket_iam_member.db_backup_writer` |
| Prefixo da geração diária | `gs://<bucket>/diario/crytto-<data-hora UTC>.sql.gz` | `infra/templates/backup.sh` |
| Agendamento | `crytto-backup.timer`, todo dia às 06:00 UTC (`backup_schedule`). Um backup também é feito na criação da VM, para existir cópia logo após o apply | `infra/templates/db.sh.tftpl` |
| Existência de cópia | Primeira cópia gerada em 23/11/2026 00:40 UTC: `diario/crytto-20261123T004027Z.sql.gz` (2,4 KiB) | `gcloud storage ls -l gs://<bucket>/diario/` |
| Custo | Ver B7: menos de US$ 0,01 no período | — |

O ciclo de vida do Cloud Storage é executado de forma assíncrona: segundo a documentação do provedor, a exclusão pode ocorrer até cerca de 24 horas depois de o objeto atingir a idade configurada. Com `age = 1`, a cópia expira em no máximo ~2 dias, dentro do limite da seção 6.3.

**Verificação (D6):**

```bash
cd infra
terraform output backup_bucket_url
BUCKET=$(terraform output -raw backup_bucket_name)
gcloud storage ls -l gs://$BUCKET/diario/                                       # cópia existente
gcloud storage buckets describe gs://$BUCKET --format="yaml(lifecycle_config,default_kms_key,soft_delete_policy,versioning_enabled)"
gcloud storage objects describe gs://$BUCKET/diario/<arquivo> --format="value(kms_key)"   # criptografia da cópia
# Na vm-db: executar um backup agora e ver a agenda
sudo systemctl start crytto-backup.service && sudo journalctl -u crytto-backup.service -n 3
systemctl list-timers crytto-backup.timer
```

**Restauração** (não exigida, mas documentada): baixar o arquivo com uma conta do grupo (a `vm-db` não consegue ler), copiar para a `vm-db` pelo bastion e executar `gunzip -c arquivo.sql.gz | docker exec -i crytto-db psql -U crytto -d crytto`.

### O que a política mínima não protege, em relação à GFS

- **Erro descoberto depois de 2 dias:** a cópia anterior ao erro já expirou; não há como desfazer.
- **Comparação ou auditoria de semanas e meses anteriores:** não há gerações semanal e mensal.
- **Perda de até 24 horas** de dados entre um dump e o seguinte (igual na GFS, que tem o mesmo RPO).
- **Falha regional:** o bucket é regional, na mesma região das VMs.
- **Comprometimento de uma conta com papel de dono no projeto:** ela consegue apagar o bucket. A GFS em produção usaria *retention policy* com bloqueio (*bucket lock*) e um projeto separado para os backups.
- **State do Terraform e senha:** não fazem parte da política mínima.

## B7. Custos

### Política conservadora (GFS): 12 meses de operação

Premissas:

| Premissa | Valor |
|---|---|
| Volume inicial do banco | 1 GB (cenário de produção; o banco atual da demonstração tem poucos KB) |
| Crescimento | +0,25 GB por mês (cerca de 3,75 GB no mês 12) |
| Tamanho de cada cópia | 25% do volume do banco (dump SQL compactado com gzip) |
| Cópias retidas | Son 7 (desde o mês 1); Father 4 no mês 1 e 5 depois; Grandfather 1 por mês acumulado, até 12 |
| Região | `us-central1`, bucket regional |

Valores unitários (lista pública do Cloud Storage para `us-central1`, a conferir na Google Cloud Pricing Calculator):

| Item | Preço |
|---|---|
| Standard (Son) | US$ 0,020 por GB/mês |
| Nearline (Father) | US$ 0,010 por GB/mês; mínimo de 30 dias; recuperação US$ 0,01/GB |
| Coldline (Grandfather) | US$ 0,004 por GB/mês; mínimo de 90 dias; recuperação US$ 0,02/GB |
| Operações classe A (uploads e cópias de promoção, ~35 por mês) | US$ 0,005 a 0,02 por 1.000 → arredondado para US$ 0,001 por mês |
| Transferência | Sem custo: VM e bucket na mesma região. A recuperação (download) só é cobrada quando há restauração |

O tamanho de cada geração usa o volume do mês em que a cópia foi feita: as cópias diárias e semanais usam o tamanho atual, e as mensais somam o tamanho de cada mês anterior.

| Mês | Volume do banco | Tamanho de uma cópia | Cópias retidas (Son + Father + Grandfather) | Volume em backup | Custo mensal estimado |
|---|---|---|---|---|---|
| 1 | 1,00 GB | 0,250 GB | 7 + 4 + 1 = 12 | 3,00 GB | US$ 0,0470 |
| 2 | 1,25 GB | 0,313 GB | 7 + 5 + 2 = 14 | 4,31 GB | US$ 0,0626 |
| 3 | 1,50 GB | 0,375 GB | 7 + 5 + 3 = 15 | 5,44 GB | US$ 0,0760 |
| 4 | 1,75 GB | 0,438 GB | 7 + 5 + 4 = 16 | 6,63 GB | US$ 0,0896 |
| 5 | 2,00 GB | 0,500 GB | 7 + 5 + 5 = 17 | 7,88 GB | US$ 0,1035 |
| 6 | 2,25 GB | 0,563 GB | 7 + 5 + 6 = 18 | 9,19 GB | US$ 0,1176 |
| 7 | 2,50 GB | 0,625 GB | 7 + 5 + 7 = 19 | 10,56 GB | US$ 0,1320 |
| 8 | 2,75 GB | 0,688 GB | 7 + 5 + 8 = 20 | 12,00 GB | US$ 0,1466 |
| 9 | 3,00 GB | 0,750 GB | 7 + 5 + 9 = 21 | 13,50 GB | US$ 0,1615 |
| 10 | 3,25 GB | 0,813 GB | 7 + 5 + 10 = 22 | 15,06 GB | US$ 0,1766 |
| 11 | 3,50 GB | 0,875 GB | 7 + 5 + 11 = 23 | 16,69 GB | US$ 0,1920 |
| 12 | 3,75 GB | 0,938 GB | 7 + 5 + 12 = 24 | 18,38 GB | US$ 0,2076 |
| **Total no ano** | | | | | **US$ 1,51** |

O custo cresce todo mês porque a geração mensal acumula cópias até completar 12, e porque o banco cresce. Mesmo no mês 12, o backup custa menos de 0,5% do custo da arquitetura implantada (US$ 49,93 por mês, cenário A).

**Parâmetro que mais influencia o custo:** a **retenção da geração Son em Standard**. No mês 12 ela responde por US$ 0,131 dos US$ 0,208 (63%), porque são 7 cópias completas na classe mais cara. Sensibilidade sobre o total anual:

| Mudança | Total no ano | Efeito |
|---|---|---|
| Política proposta | US$ 1,51 | — |
| Son com 30 cópias diárias (em vez de 7) | US$ 4,78 | +216% |
| Grandfather em Standard (em vez de Coldline) | US$ 2,10 | +39% |

Reduzir a retenção diária (por exemplo, de 7 para 3 dias) baixaria o custo, mas o grupo perderia a capacidade de voltar a qualquer dia da última semana: um erro percebido no 4º dia só poderia ser desfeito pela cópia semanal, com até 7 dias de perda. Trocar o Grandfather para Archive (US$ 0,0012/GB) economizaria pouco em valor absoluto e traria mínimo de 365 dias e recuperação mais cara.

### Política mínima: período do trabalho

| Item | Estimativa |
|---|---|
| Armazenamento | No máximo 2 cópias de ~2,5 KiB (expiração em 1 dia) → menos de US$ 0,0001 |
| Operações | 1 upload por dia + 1 na criação + testes, menos de 50 operações classe A → menos de US$ 0,001 |
| Chave KMS | Já existente para os discos (S6); o bucket não adiciona custo de chave, apenas operações de criptografia (centavos por 10.000) |
| **Total no período** | **Menos de US$ 0,01** (próximo de zero) |
