# Automação Ansible

Este diretório contém exclusivamente o código Ansible da Crytto RPG Platform v2.

## Arquivos

- `inventory.ini`: hosts `app` e `db` da rede privada do Vagrant.
- `group_vars/all.yml`: portas, IPs, banco e parâmetros da aplicação.
- `templates/app.env.j2`: template das variáveis de ambiente.
- `playbook.yml`: instala Docker, sincroniza o projeto, sobe os serviços e valida health checks.

## Execução

Pré-requisitos:

- VMs criadas e acessíveis por SSH.
- Ansible instalado na máquina de controle.
- Chaves Vagrant disponíveis em `.vagrant/machines/*/virtualbox/private_key`.

A partir da raiz do projeto:

```bash
vagrant up app db
ansible-playbook -i infra/ansible/inventory.ini infra/ansible/playbook.yml
```

## O que o playbook faz

1. Instala `docker.io`, `docker-compose` e `rsync` nas VMs.
2. Habilita e inicia o serviço Docker.
3. Cria `/opt/crytto-rpg-platform-v2`.
4. Sincroniza o código para a VM de aplicação e para a VM de banco.
5. Gera o `.env` a partir do template Jinja2.
6. Sobe Postgres na VM `db`.
7. Sobe frontend/backend na VM `app`.
8. Valida Postgres, backend `/health` e frontend HTTP.

O playbook não usa `rsync --delete`, portanto arquivos criados na VM não são apagados em reaplicações.
