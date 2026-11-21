# Declaração de uso de IA

Grupo: Pedro Henrique de Oliveira, Victor Nascimento Silva, Ana Luiza Ripoli Theodorovitz e João Pedro Foster Ruiz.

## Ferramentas utilizadas

| Ferramenta | Onde foi usada |
|---|---|
| GitHub Copilot Chat (VS Code) | Análise do enunciado da Entrega 1 em relação ao repositório, rascunho dos textos de `docs/arquitetura.md`, dos três ADRs, do `README.md`, do `IA.md` e do `.drawio`, e revisão das estimativas da calculadora e das branches do grupo |

## O que o grupo verificou ou corrigiu

| Item gerado | Verificação ou correção feita pelo grupo |
|---|---|
| Provedor e arquitetura | O grupo escolheu a GCP por já ter conta com créditos. O repositório vinha de uma versão em Cloud Run; a arquitetura foi redefinida para VPC, sub-redes, bastion, VMs e Cloud NAT, como exige o enunciado. |
| Estimativa de custos | Valores calculados pelo grupo na Google Cloud Pricing Calculator. Foi Feito dois cenários com preços diferentes. |
| ADR-002 (saída para a internet) | A Ana escreveu o rascunho original. |
| Diagrama | A Ana criou a estrutura inicial no draw.io. A IA gerou um arquivo base com CIDRs, sub-redes e os três fluxos; o grupo ajusta o layout e exporta a imagem. |
| CIDRs, rotas, matriz de segurança e tamanhos de instância | Rascunho gerado pela IA e revisado pelo grupo contra a documentação da GCP (VPC, rotas, firewall e tipos de máquina E2). |

## Entrega 2

| Ferramenta | Onde foi usada |
|---|---|
| GitHub Copilot (VS Code) | Leitura do enunciado e divisão de tarefas ([docs/TAREFAS-ENTREGA2.md](docs/TAREFAS-ENTREGA2.md)); rascunho do código Terraform da parte do Pedro (`versions.tf`, `providers.tf`, `variables.tf`, `locals.tf`, `project.tf`, `kms.tf`, `secrets.tf`, `iam.tf`, `compute.tf`, `outputs.tf`), dos startup scripts em `infra/templates/`, do `docker-compose.gcp.yml`, do `nginx.https.conf` e dos textos do README, da errata e de `docs/seguranca.md` (S1, S3 a S6) |

| Item gerado | Verificação ou correção feita pelo grupo |
|---|---|
| Código Terraform | `terraform fmt -check` e `terraform validate` executados; versões dos providers conferidas no Terraform Registry. Conferir `terraform plan` no primeiro apply real. |
| Startup scripts | Verificados com `bash -n` e `shellcheck` após renderização dos templates. |
| HTTPS e Compose da nuvem | Testados localmente com Docker: redirecionamento 301 de HTTP para HTTPS, TLS com certificado autoassinado, `/health` com banco ativo, gravação e leitura pela API e porta 3001 não publicada. |
| Senha fora do state (write-only) | Conferido na documentação do provider `google` (`secret_data_wo`) e do Terraform (variáveis efêmeras). |

