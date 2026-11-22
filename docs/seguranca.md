# Segurança da infraestrutura (Victor Nascimento Silva)

## S1 - Desabilitação de autenticação por senha e acesso root

O controle S1 foi implementado com o objetivo de reduzir a superfície de ataque de acesso administrativo às VMs. A configuração de segurança exige que:

- `PasswordAuthentication no` para impedir que o SSH aceite credenciais de senha;
- `PermitRootLogin no` para garantir que o acesso root direto não seja permitido;
- o uso de chaves SSH como mecanismo principal de acesso, com o bastion como ponto de entrada para administração.

Essa regra deve ser aplicada em todas as VMs do projeto e reforçada em scripts de inicialização ou documentação operacional. Com isso, mesmo que um atacante descubra a senha de um usuário local, ele não consegue explorar SSH por autenticação por senha nem entrar diretamente como `root`.

Implementação: o arquivo `infra/ssh-hardening.sh` configura `PasswordAuthentication no`, `KbdInteractiveAuthentication no` e `PermitRootLogin no`, valida a configuração e recarrega o servidor SSH. O script deve ser anexado ao metadata `startup-script` de todas as VMs.

## S2 - Saída restrita da sub-rede privada

O controle S2 foi ajustado para aplicar o princípio do menor privilégio no egress da rede privada. Na arquitetura anterior, a saída era aberta para qualquer destino. Agora, a regra está alinhada ao modelo esperado:

- `HTTP` e `HTTPS` permitidos para atualização de pacotes e acesso externo necessário;
- `DNS` permitido nas portas 53/TCP e 53/UDP;
- a porta `5432` liberada apenas da `vm-app` para a `vm-db`;
- acesso de saída público para outros destinos bloqueado por padrão.

Essa medida reduz o risco de movimentação lateral e limita a capacidade de uma VM privada comunicar-se com qualquer endpoint externo. O tráfego para o banco fica restrito ao fluxo de negócio esperado e não é permitido a partir de outras instâncias.

## Observações de implementação

- A sub-rede privada (`priv-a`) fica em `10.20.10.0/24` e usa o Cloud NAT para saída para a internet.
- A sub-rede pública (`pub-a`) fica em `10.20.1.0/24` e suporta os acessos públicos e administrativos autorizados.
- O acesso SSH só é liberado a partir do CIDR informado pela variável `admin_source_cidr`, nunca em `0.0.0.0/0`.
- O banco permanece sem endereço IP público e é acessível apenas pela aplicação e pelo bastion, conforme a política de rede definida.

## Referência

A política de rede e de acesso descrita aqui está alinhada com a matriz de regras de segurança definida no documento de arquitetura da Entrega 1 e com os requisitos de rede e firewall da Entrega 2.
