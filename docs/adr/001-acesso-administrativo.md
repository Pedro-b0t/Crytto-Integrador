# ADR-001: Estratégia de acesso administrativo

No contexto de uma infraestrutura com banco em sub-rede privada que precisa de administração por SSH,
diante da necessidade de acesso administrativo sem expor as instâncias internas à internet,
decidimos usar uma VM bastion na sub-rede pública, com SSH liberado somente para o IP do grupo (`/32`),
e descartamos IP público direto nas instâncias e o acesso por serviço gerenciado (Identity-Aware Proxy com OS Login),
para ter um ponto único e controlado de entrada, com demonstração de SSH exigida na Entrega 2,
aceitando que o grupo paga por uma VM e um IP externo estático extras, mantém e atualiza o bastion por conta própria, e precisa editar a regra de firewall sempre que o IP do grupo mudar, o que pode bloquear o acesso até a correção.
