# Declaração de uso de IA

Grupo: Pedro Henrique de Oliveira, Victor Nascimento Silva, Ana Luiza Ripoli Theodorovitz e João Pedro Foster Ruiz.

## Ferramentas utilizadas

| Ferramenta | Onde foi usada |
|---|---|
| GitHub Copilot Chat (VS Code) | Análise do enunciado da Entrega 1 em relação ao repositório, rascunho dos textos de `docs/arquitetura.md`, dos três ADRs, do `README.md`, do `IA.md` e do `.drawio`, e revisão das estimativas da calculadora e das branches do grupo |
| ChatGPT (OpenAI) | Apoio à elaboração da proposta de alta disponibilidade, documentação H1–H7, ADR-004, análise de segurança, interpretação dos relatórios Checkov e Gitleaks e organização das evidências da Entrega 2. |

## O que o grupo verificou ou corrigiu

| Item gerado | Verificação ou correção feita pelo grupo |
|---|---|
| Provedor e arquitetura | O grupo escolheu a GCP por já ter conta com créditos. O repositório vinha de uma versão em Cloud Run; a arquitetura foi redefinida para VPC, sub-redes, bastion, VMs e Cloud NAT, como exige o enunciado. |
| Estimativa de custos | Valores calculados pelo grupo na Google Cloud Pricing Calculator. Foi Feito dois cenários com preços diferentes. |
| ADR-002 (saída para a internet) | A Ana escreveu o rascunho original. |
| Diagrama | A Ana criou a estrutura inicial no draw.io. A IA gerou um arquivo base com CIDRs, sub-redes e os três fluxos; o grupo ajusta o layout e exporta a imagem. |
| CIDRs, rotas, matriz de segurança e tamanhos de instância | Rascunho gerado pela IA e revisado pelo grupo contra a documentação da GCP (VPC, rotas, firewall e tipos de máquina E2). |

## Uso de IA na Entrega 2 — Ana Luiza Ripoli

O ChatGPT foi utilizado como ferramenta de apoio na elaboração
da documentação de alta disponibilidade e na análise de segurança.
Os comandos foram executados no ambiente local, e os
resultados das verificações foram registrados como evidências.
As recomendações de segurança ainda dependem de validação
e, quando necessário, de implementação pelos responsáveis.