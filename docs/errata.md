# Errata — Entrega 2

Este documento registra as alterações realizadas em relação à
Entrega 1 do projeto Crytto.

## Alta disponibilidade — Ana Luiza Ripoli

Na Entrega 1, a arquitetura apresentava pontos únicos de falha,
pois utilizava uma única zona e apenas uma instância da aplicação
e do banco de dados.

Na Entrega 2, foi elaborada uma proposta de alta disponibilidade,
sem implantação, incluindo:

- Distribuição da aplicação em duas zonas.
- Load balancer com verificações de integridade (health checks).
- Duas instâncias da aplicação.
- Estratégia de Cloud NAT para saída à internet.
- Banco de dados com alta disponibilidade.
- Análise dos riscos e comparação dos custos.

A decisão arquitetural está documentada no ADR-004.

## Segurança — Ana Luiza Ripoli

Foi realizada uma análise de segurança utilizando Checkov e
Gitleaks.

O Checkov identificou três verificações com falha:
uma relacionada a uma credencial do PostgreSQL armazenada
em arquivo de configuração e duas relacionadas ao uso de HTTP
nas verificações locais de integridade.

O Gitleaks analisou 20 commits e não identificou vazamentos
pelas regras da ferramenta.

Também foram realizadas melhorias no arquivo
`infra/ansible/playbook.yml`:

- Permissão do arquivo `.env` alterada de `0644` para `0600`.
- Inclusão de `no_log: true` na tarefa de geração do `.env`.

A credencial identificada pelo Checkov permanece pendente
de correção pelo responsável pelo requisito S4.

Os resultados e as decisões de segurança estão documentados
em `docs/seguranca.md`, com evidências em `docs/evidencias/`.

## Observações

A proposta de alta disponibilidade é apenas arquitetural e
não foi implantada na infraestrutura da Entrega 2.

As alterações de segurança realizadas no Ansible ainda
precisam ser validadas durante a implantação.