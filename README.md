# Crytto RPG Platform v2

Versão independente do projeto original, preparada para execução e deploy em VM com automação de infraestrutura.

## Objetivo da v2

- Manter o projeto original intacto (Cloud Run).
- Disponibilizar uma versão isolada focada em VM.
- Automatizar provisionamento e configuração com Vagrant + Ansible.

## Stack técnica

- Frontend: React 18 + TypeScript + Vite, servido por nginx.
- Backend: Node.js + Express.
- Banco: Postgres 16.
- Orquestração local/VM: Docker Compose.
- Provisionamento da VM: Vagrant (VirtualBox).
- Configuração da VM: Ansible (agentless).

## Estrutura de automação

- `Vagrantfile`: cria e configura 2 VMs Ubuntu (app e db).
- `infra/ansible/inventory.ini`: inventário/hosts e conexão SSH.
- `infra/ansible/group_vars/all.yml`: variáveis parametrizáveis.
- `infra/ansible/templates/app.env.j2`: template dinâmico de ambiente.
- `infra/ansible/playbook.yml`: provisionamento idempotente e deploy da stack.
- `deploy.ps1` / `deploy.sh`: execução automatizada ponta a ponta.

## Pré-requisitos

1. VirtualBox instalado.
2. Vagrant instalado.
3. Ansible instalado na máquina de controle ou no WSL (recomendado no Windows).
4. Docker não é obrigatório no host, pois será instalado nas VMs.

No Windows, instale o WSL e o Ansible uma vez:

```powershell
wsl --install -d Ubuntu
```

Dentro do Ubuntu/WSL:

```bash
sudo apt update
sudo apt install -y ansible
```

## Como subir a v2

### Windows

```powershell
.\deploy.ps1
```

O script usa Ansible nativo quando disponível ou Ansible instalado no WSL automaticamente.

### Linux/macOS

```bash
chmod +x deploy.sh
./deploy.sh
```

Após concluir:

- Frontend: http://localhost:8080
- Backend: http://localhost:3001
- Postgres: localhost:5433 (encaminhado para a VM db na porta 5432)

## Execução manual (opcional)

```bash
vagrant up
ansible-playbook -i infra/ansible/inventory.ini infra/ansible/playbook.yml
```

No Windows sem Ansible nativo, execute o segundo comando dentro do Ubuntu/WSL a partir desta pasta.

## Validações

- Health backend: `GET http://localhost:3001/health`
- Frontend: `GET http://localhost:8080` (ou consulte `vagrant port app 80` se houver colisão de portas)
- Postgres: conexão em `localhost:5433` no host (ou `192.168.56.22:5432` na rede privada).
- Playbook pode ser executado mais de uma vez sem duplicar configuração crítica.

## Cloud Run na v2

- A v2 não faz deploy em Cloud Run.
- Não há pipeline de CI/CD ativa nesta versão; o deploy é manual/automatizado via Vagrant + Ansible.

## Referências

- [ARQUITETURA.md](./ARQUITETURA.md)
- [docs/VM-MIGRATION.md](./docs/VM-MIGRATION.md)
