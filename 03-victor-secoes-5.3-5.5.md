
## 5.3 Plano de endereçamento IP

| Recurso | Nome | CIDR | Zona | Tipo | Finalidade |
|---|---|---|---|---|---|
| Rede virtual | `vpc-grupo-x` | `10.20.0.0/16` | global | modo custom | Rede do projeto |
| Sub-rede | `pub-a` | `10.20.1.0/24` | `us-central1` (VMs em `us-central1-a`) | Pública | Bastion e aplicação |
| Sub-rede | `priv-a` | `10.20.10.0/24` | `us-central1` (VMs em `us-central1-a`) | Privada | Banco de dados |

**IPs internos fixos:** `vm-bastion` `10.20.1.10`, `vm-app` `10.20.1.20`, `vm-db` `10.20.10.10`.

**Justificativa.** Os blocos seguem a faixa privada `10.0.0.0/8` (RFC 1918) e não se sobrepõem. Cada `/24` tem 256 endereços; a GCP reserva 4 em cada sub-rede (rede, gateway, penúltimo e broadcast), restando 252 utilizáveis. O tamanho é muito maior que as 3 VMs atuais, mas permite adicionar instâncias na Entrega 2 (alta disponibilidade) sem recriar a rede. Usar `10.20.0.0/16` na VPC deixa espaço para novas sub-redes (por exemplo, uma segunda zona).

## 5.4 Tabelas de rota

| Sub-rede | Destino | Alvo (next hop) | Observação |
|---|---|---|---|
| `pub-a` | `10.20.1.0/24` | local (rota da sub-rede) | Criada automaticamente |
| `pub-a` | `10.20.10.0/24` | local (rota da sub-rede) | Tráfego interno entre sub-redes |
| `pub-a` | `0.0.0.0/0` | `default-internet-gateway` | VMs com IP externo saem e recebem tráfego direto |
| `priv-a` | `10.20.10.0/24` | local (rota da sub-rede) | Criada automaticamente |
| `priv-a` | `10.20.1.0/24` | local (rota da sub-rede) | Acesso a partir da aplicação e do bastion |
| `priv-a` | `0.0.0.0/0` | `default-internet-gateway`, atendida pelo Cloud NAT | A rota é a mesma da VPC; sem IP externo, a saída só funciona por meio do NAT |

Na GCP, as rotas pertencem à VPC e valem para todas as sub-redes. O que diferencia `priv-a` é a ausência de IP externo nas VMs.

**Sem o NAT.** A `vm-db` perderia a saída para a internet: `apt update`, instalação de pacotes e `docker pull` falhariam, e as atualizações de segurança do banco deixariam de ser aplicadas. A aplicação continuaria funcionando, mas a instalação automatizada da Entrega 2 não seria possível.

## 5.5 Matriz de regras de segurança

Na GCP, o papel de "security group" é feito por regras de firewall da VPC com tags de rede. Os nomes `sg-*` abaixo identificam o grupo lógico de cada papel. O tráfego de entrada não listado é negado por padrão.

| Grupo de segurança | Direção | Protocolo | Porta | Origem/Destino | Justificativa |
|---|---|---|---|---|---|
| `sg-bastion` (tag `bastion`) | Entrada | TCP | 22 | IP público do grupo (`/32`) | Acesso administrativo restrito ao IP do grupo; SSH nunca liberado para `0.0.0.0/0` |
| `sg-app` (tag `app`) | Entrada | TCP | 80, 443 | `0.0.0.0/0` | Acesso público ao frontend e à API |
| `sg-app` | Entrada | TCP | 22 | `sg-bastion` (tag `bastion`) | SSH apenas via bastion |
| `sg-db` (tag `db`) | Entrada | TCP | 5432 | `sg-app` (tag `app`) | Banco acessível somente pela aplicação |
| `sg-db` | Entrada | TCP | 22 | `sg-bastion` (tag `bastion`) | Administração do banco via bastion |
| Todos | Saída | Todos | Todos | `0.0.0.0/0` | Regra padrão de saída; `vm-db` sai pelo Cloud NAT |

**Princípio do menor privilégio.** A porta 3001 do backend não é aberta: o nginx faz o proxy dentro da própria `vm-app`. O banco não tem IP externo e só aceita conexões de origens internas específicas, referenciadas por tag em vez de faixas de IP.
