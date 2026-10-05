# ADR-002: Saída para a internet da sub-rede privada

No contexto de um banco de dados em sub-rede privada, sem IP externo, que precisa baixar pacotes e imagens Docker,
diante da necessidade de acesso de saída para a internet sem aceitar conexões iniciadas de fora,
decidimos usar o Cloud NAT (NAT gerenciado), associado a um Cloud Router,
e descartamos o NAT em instância (VM com `iptables` e rota customizada) e a ausência de saída,
para não manter uma VM de roteamento, evitar um novo ponto único de falha e permitir a instalação automatizada da aplicação,
aceitando que o Cloud NAT é cobrado por hora do gateway e por GiB processado mesmo com pouco tráfego, o que o torna um dos itens mais caros da estimativa e exige destruir o ambiente entre as sessões de teste para reduzir o custo.
