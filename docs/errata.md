# Errata

## Victor Nascimento Silva

- **ADR afetado:** ADR-002 - saída da rede privada para a internet.
- **Mudança:** na Entrega 1, a saída da infraestrutura era aberta para todos os destinos. Na Entrega 2, a saída da `vm-db` foi restringida a DNS (53) e HTTP/HTTPS (80/443), com uma regra de negação para todo o restante.
- A `vm-app` permite HTTP/HTTPS/DNS e somente o tráfego PostgreSQL TCP/5432 destinado à `vm-db`.
- Foi acrescentada a VM `vm-db` em `priv-a` (`10.20.10.10`) sem configuração de IP público.
