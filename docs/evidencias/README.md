# Evidências da Entrega 2

Capturas de tela e relatórios, sem IDs de conta de faturamento, telefones, e-mails, chaves, senhas ou tokens. Capturas feitas em 22/11/2026 com o ambiente criado pelo Terraform no projeto `crytto-integrador`.

## Conta e custos

| Evidência | Arquivo |
|---|---|
| Alerta de orçamento (R$ 100/mês, alertas em 50%, 90% e 100%), criado antes do primeiro apply | [orcamento-alerta.png](orcamento-alerta.png) |
| MFA (verificação em duas etapas) ativado na conta usada pelo grupo (S8) | [mfa.png](mfa.png) |

## Demonstrações

| Demo | Evidência | Arquivo |
|---|---|---|
| D1 | `terraform plan` sem alterações e `terraform output` | [d1-plan-output.png](d1-plan-output.png) |
| D2 | Aplicação por HTTPS no navegador (marketplace, compra e saldo de Crytts gravados no PostgreSQL) | [d2-app-navegador.png](d2-app-navegador.png) |
| D2 | Negociação TLS e `/health` com o banco ativo (S3) | [d2-https-health.png](d2-https-health.png) |
| D2 | HTTP responde 301 para HTTPS (S3) | [d2-redirect-http.png](d2-redirect-http.png) |
| D3 | SSH no bastion com a chave do grupo | [d3-ssh-bastion.png](d3-ssh-bastion.png) |
| D3 / D4 | Salto pelo bastion até a `vm-db` e IP de saída igual ao do Cloud NAT (`35.225.80.150`) | [d3-d4-salto-vm-db-saida-nat.png](d3-d4-salto-vm-db-saida-nat.png) |
| D3 | Autenticação por senha recusada: `Permission denied (publickey)` (S1) | [d3-senha-recusada.png](d3-senha-recusada.png) |
| D4 | Output do IP público do NAT | [d4-nat-output.png](d4-nat-output.png) |
| D4 | `vm-db` sem IP externo | [d4-vm-db-sem-ip-publico.png](d4-vm-db-sem-ip-publico.png) |
| D5 | Código só com nomes de variáveis e recursos, nenhum valor de senha (S4) | [d5-git-grep-password.png](d5-git-grep-password.png) |
| D5 | State do Terraform sem a senha (`secret_data_wo = (write-only attribute)`) (S4) | [d5-state-sem-senha.png](d5-state-sem-senha.png) |
| D5 | Achado corrigido (`CKV_SECRET_4`) e aceito (`GCP-0031`): tabela em [../seguranca.md](../seguranca.md) | relatórios abaixo |
| D6 | Bucket de backup com regra de ciclo de vida e criptografia Cloud KMS (console) | [d6-bucket-console.png](d6-bucket-console.png) |
| D6 | Cópia existente em `diario/` | [d6-copia-existente.png](d6-copia-existente.png) |
| D6 | Retenção de 1 dia em `diario/` e chave CMEK | [d6-retencao-criptografia.png](d6-retencao-criptografia.png) |

## Análise automatizada (S7)

| Relatório | Arquivo |
|---|---|
| Checkov no Ansible | [checkov-antes.txt](checkov-antes.txt) |
| Checkov no Terraform | [checkov-terraform.txt](checkov-terraform.txt) |
| Trivy no Terraform completo | [trivy-terraform.txt](trivy-terraform.txt) |
| Gitleaks no histórico | [gitleaks-relatorio.json](gitleaks-relatorio.json), [gitleaks-final.json](gitleaks-final.json) |

## Após a apresentação

| Evidência | Arquivo | Status |
|---|---|---|
| `terraform destroy` e console sem NAT, IPs, discos, snapshots nem buckets | `destroy.png` | Até 24 h após a apresentação |
