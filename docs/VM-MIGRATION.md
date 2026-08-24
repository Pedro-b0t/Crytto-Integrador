# Migração de Infraestrutura para VM - Crytto RPG Platform v2

## 1. Diagnóstico da versão original

### Stack e arquitetura

- Frontend em React + TypeScript + Vite, empacotado em imagem nginx.
- Backend em Node.js/Express com conexão Postgres via `DATABASE_URL`.
- Persistência com Postgres e suporte local via Docker Compose.

### Infraestrutura original

- Deploy automatizado para Google Cloud Run via workflow GitHub Actions na versão original.
- Scripts de deploy em Cloud Run (`deploy.sh`, `deploy.ps1` na versão original).
- Uso de `gcloud run deploy` e configuração de imagens no Artifact Registry.

## 2. Estratégia da v2

- Cópia integral do projeto para pasta independente: `Crytto-RPG-Platform-v2`.
- Substituição da estratégia de deploy para VM baseada em:
  - Vagrant + VirtualBox (provisionamento da VM)
  - Ansible (configuração idempotente)
  - Docker Compose (execução contínua dos serviços)
- Topologia adotada:
  - VM app: frontend + backend
  - VM db: Postgres

## 3. Alterações realizadas na v2

1. Provisionamento VM:
- `Vagrantfile`

2. Config management (Ansible):
- `infra/ansible/inventory.ini`
- `infra/ansible/group_vars/all.yml`
- `infra/ansible/templates/app.env.j2`
- `infra/ansible/playbook.yml`

3. Deploy scripts adaptados:
- `deploy.ps1`
- `deploy.sh`

4. Ajustes de runtime:
- `backend/src/index.js` para bind em `0.0.0.0`.
- `docker-compose.yml` parametrizado por variáveis de ambiente.

5. CI/CD removido na v2:
- Sem workflow de CI/CD ativo; execução e deploy ficam centralizados na automação de VM.

## 4. Cobertura dos requisitos técnicos obrigatórios

- Virtualização: VM Ubuntu em VirtualBox via Vagrant.
- Virtualização: 2 VMs Ubuntu em VirtualBox via Vagrant (app e db).
- Inventário/hosts: `infra/ansible/inventory.ini`.
- Scripts de automação: `deploy.ps1`, `deploy.sh`, `infra/ansible/playbook.yml`.
- Idempotência: playbook pode ser reaplicado para convergir estado.
- Variáveis/templates: `group_vars/all.yml` + `templates/app.env.j2`.
- Conectividade automatizada: SSH via chave do Vagrant no inventário.
- App funcionando ao final: docker compose sobe frontend, backend e banco.
- App funcionando ao final: compose da VM app sobe frontend/backend e compose da VM db sobe o Postgres.
- Documentação: este arquivo + README v2.

## 5. Execução

```bash
vagrant up
ansible-playbook -i infra/ansible/inventory.ini infra/ansible/playbook.yml
```

Endpoints esperados no host:

- Frontend: `http://localhost:8080`
- Backend: `http://localhost:3001`
- Postgres: `localhost:5433` (forward da VM db `5432`)
