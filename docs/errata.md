# Errata: diverg├¬ncias entre a Entrega 1 e o que foi implantado

Toda mudan├ºa em rela├º├úo ao projeto da Entrega 1 ([arquitetura.md](arquitetura.md)) ├® registrada aqui, com o motivo. Mudan├ºas em decis├Áes citam o ADR afetado; o ADR original recebe status "substitu├¡da" e um novo ADR ├® criado.

| # | Item da Entrega 1 | O que foi implantado | Motivo | ADR afetado | Respons├ível |
|---|---|---|---|---|---|
| 1 | 5.6: Terraform `>= 1.6` e provider `hashicorp/google ~> 6.0` | Terraform `= 1.17.2`, `hashicorp/google = 6.50.0` e `hashicorp/random = 3.9.1`, fixados em `infra/versions.tf`, com `.terraform.lock.hcl` versionado | A se├º├úo 7.2 do enunciado exige vers├Áes fixadas. O Terraform 1.11+ ├® necess├írio para vari├íveis ef├¬meras e argumentos write-only, usados para manter a senha do banco fora do state (S4). O provider `random` gera o sufixo do key ring do KMS | Nenhum | Pedro |
| 2 | 5.6: instala├º├úo da aplica├º├úo com Ansible + Docker Compose | Startup scripts do Compute Engine ([infra/templates/](../infra/templates/)), gravados pelo Terraform nos metadados das VMs, + Docker Compose ([docker-compose.gcp.yml](../docker-compose.gcp.yml)). O Ansible continua no reposit├│rio apenas para a execu├º├úo local com Vagrant | As VMs privadas s├│ s├úo alcan├º├íveis pelo bastion e o ambiente ├® recriado a cada sess├úo de teste (plano de custos, 5.9). O startup script roda sozinho a cada cria├º├úo, sem n├│ de controle Ansible (que exigiria WSL nas m├íquinas Windows do grupo) | Nenhum | Pedro |
| 9 | Entrega 1: arquivo `.env` gerado pelo Ansible sem restrição específica de leitura | Na configuração local do Ansible, o arquivo `.env` passou a ser criado com permissão `0600`, e a tarefa de geração recebeu `no_log: true` em `infra/ansible/playbook.yml` | Restringir o acesso às credenciais locais e evitar sua exposição nos logs de execução do Ansible | Nenhum | Ana |
| 3 | 5.10, risco 9: tr├ífego p├║blico em HTTP at├® configurar certificado | HTTPS na `vm-app` com certificado autoassinado para o IP est├ítico; HTTP (porta 80) apenas redireciona para HTTPS ([nginx.https.conf](../nginx.https.conf)) | Controle S3 da Entrega 2. Sem dom├¡nio pr├│prio, n├úo ├® poss├¡vel emitir certificado p├║blico para um IP | Nenhum | Pedro |
| 4 | 5.1/5.6: credenciais do banco fixas (`crytto/crytto`) nos arquivos Compose | Senha fornecida por `TF_VAR_db_password`, gravada no Secret Manager (`crytto-db-password`) e lida pelas VMs com a pr├│pria service account. Os arquivos Compose da nuvem n├úo cont├¬m senha | Controles S4 e S5. Recursos novos n├úo previstos no diagrama: Secret Manager e service accounts `sa-vm-app` e `sa-vm-db` (custo pr├│ximo de zero) | Nenhum | Pedro |
| 5 | 5.7: discos `pd-balanced` com a criptografia padr├úo do Google | Discos de boot cifrados com chave gerenciada pelo cliente (CMEK) no Cloud KMS, declarada em `infra/kms.tf` | Controle S6 exige criptografia declarada explicitamente no c├│digo. Recurso novo: key ring e chave KMS (cerca de US$ 0,06 por m├¬s por vers├úo de chave) | Nenhum | Pedro |
| 6 | 5.7: VMs sem configura├º├úo adicional de seguran├ºa | Shielded VM (secure boot, vTPM e monitoramento de integridade), chaves SSH de projeto bloqueadas e console serial desativado em todas as VMs | Redu├º├úo de achados da an├ílise de IaC (S7) sem custo adicional | Nenhum | Pedro |
| 7 | 5.5: backend Node.js na porta 3001 exposto no host pelo `docker-compose.app.yml` | Na nuvem, a porta 3001 n├úo ├® publicada: o backend s├│ ├® alcan├ºado pelo nginx na rede interna do Compose | Menor privil├®gio, coerente com a matriz 5.5, que j├í n├úo abria a 3001 no firewall | Nenhum | Pedro |
| 8 | Entrega 1: cr├®dito promocional GCP v├ílido at├® 27/10/2026 | Os custos da Entrega 2 s├úo pagos pelo grupo | O cr├®dito expirou antes do per├¡odo de testes (risco 8 da se├º├úo 5.10) | Nenhum | Pedro |

## A registrar pelos demais integrantes

| Tema | Diverg├¬ncia esperada | Respons├ível |
|---|---|---|
| Matriz 5.5, regra de sa├¡da "Todos / Todos / `0.0.0.0/0`" | Sa├¡da restrita (S2): HTTP/HTTPS e DNS para pacotes e 5432 apenas da `vm-app` para a `vm-db` | Victor |
| ADR-003, consequ├¬ncia "o grupo fica respons├ível por backup" e risco 6 (sem backup automatizado) | Pol├¡tica m├¡nima de backup configurada por Terraform; avaliar se o ADR-003 continua v├ílido ou se um novo ADR o complementa (ADR-005) | Jo├úo |
| Diagrama 5.2 | Atualizar o diagrama implantado se a implanta├º├úo divergir (Secret Manager, KMS e service accounts), mantendo a proposta de HA em arquivo separado | Ana |

## Incidentes de seguran├ºa

Nenhum at├® o momento. Se uma credencial, chave privada ou `tfstate` for commitada, registrar aqui: data, o que vazou, commit, revoga├º├úo feita e como foi removida.
