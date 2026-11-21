# Errata: divergências entre a Entrega 1 e o que foi implantado

Toda mudança em relação ao projeto da Entrega 1 ([arquitetura.md](arquitetura.md)) é registrada aqui, com o motivo. Mudanças em decisões citam o ADR afetado; o ADR original recebe status "substituída" e um novo ADR é criado.

| # | Item da Entrega 1 | O que foi implantado | Motivo | ADR afetado | Responsável |
|---|---|---|---|---|---|
| 1 | 5.6: Terraform `>= 1.6` e provider `hashicorp/google ~> 6.0` | Terraform `= 1.17.2`, `hashicorp/google = 6.50.0` e `hashicorp/random = 3.9.1`, fixados em `infra/versions.tf`, com `.terraform.lock.hcl` versionado | A seção 7.2 do enunciado exige versões fixadas. O Terraform 1.11+ é necessário para variáveis efêmeras e argumentos write-only, usados para manter a senha do banco fora do state (S4). O provider `random` gera o sufixo do key ring do KMS | Nenhum | Pedro |
| 2 | 5.6: instalação da aplicação com Ansible + Docker Compose | Startup scripts do Compute Engine ([infra/templates/](../infra/templates/)), gravados pelo Terraform nos metadados das VMs, + Docker Compose ([docker-compose.gcp.yml](../docker-compose.gcp.yml)). O Ansible continua no repositório apenas para a execução local com Vagrant | As VMs privadas só são alcançáveis pelo bastion e o ambiente é recriado a cada sessão de teste (plano de custos, 5.9). O startup script roda sozinho a cada criação, sem nó de controle Ansible (que exigiria WSL nas máquinas Windows do grupo) | Nenhum | Pedro |
| 3 | 5.10, risco 9: tráfego público em HTTP até configurar certificado | HTTPS na `vm-app` com certificado autoassinado para o IP estático; HTTP (porta 80) apenas redireciona para HTTPS ([nginx.https.conf](../nginx.https.conf)) | Controle S3 da Entrega 2. Sem domínio próprio, não é possível emitir certificado público para um IP | Nenhum | Pedro |
| 4 | 5.1/5.6: credenciais do banco fixas (`crytto/crytto`) nos arquivos Compose | Senha fornecida por `TF_VAR_db_password`, gravada no Secret Manager (`crytto-db-password`) e lida pelas VMs com a própria service account. Os arquivos Compose da nuvem não contêm senha | Controles S4 e S5. Recursos novos não previstos no diagrama: Secret Manager e service accounts `sa-vm-app` e `sa-vm-db` (custo próximo de zero) | Nenhum | Pedro |
| 5 | 5.7: discos `pd-balanced` com a criptografia padrão do Google | Discos de boot cifrados com chave gerenciada pelo cliente (CMEK) no Cloud KMS, declarada em `infra/kms.tf` | Controle S6 exige criptografia declarada explicitamente no código. Recurso novo: key ring e chave KMS (cerca de US$ 0,06 por mês por versão de chave) | Nenhum | Pedro |
| 6 | 5.7: VMs sem configuração adicional de segurança | Shielded VM (secure boot, vTPM e monitoramento de integridade), chaves SSH de projeto bloqueadas e console serial desativado em todas as VMs | Redução de achados da análise de IaC (S7) sem custo adicional | Nenhum | Pedro |
| 7 | 5.5: backend Node.js na porta 3001 exposto no host pelo `docker-compose.app.yml` | Na nuvem, a porta 3001 não é publicada: o backend só é alcançado pelo nginx na rede interna do Compose | Menor privilégio, coerente com a matriz 5.5, que já não abria a 3001 no firewall | Nenhum | Pedro |
| 8 | Entrega 1: crédito promocional GCP válido até 27/10/2026 | Os custos da Entrega 2 são pagos pelo grupo | O crédito expirou antes do período de testes (risco 8 da seção 5.10) | Nenhum | Pedro |

## A registrar pelos demais integrantes

| Tema | Divergência esperada | Responsável |
|---|---|---|
| Matriz 5.5, regra de saída "Todos / Todos / `0.0.0.0/0`" | Saída restrita (S2): HTTP/HTTPS e DNS para pacotes e 5432 apenas da `vm-app` para a `vm-db` | Victor |
| ADR-003, consequência "o grupo fica responsável por backup" e risco 6 (sem backup automatizado) | Política mínima de backup configurada por Terraform; avaliar se o ADR-003 continua válido ou se um novo ADR o complementa (ADR-005) | João |
| Diagrama 5.2 | Atualizar o diagrama implantado se a implantação divergir (Secret Manager, KMS e service accounts), mantendo a proposta de HA em arquivo separado | Ana |

## Incidentes de segurança

Nenhum até o momento. Se uma credencial, chave privada ou `tfstate` for commitada, registrar aqui: data, o que vazou, commit, revogação feita e como foi removida.
