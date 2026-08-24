# deploy.ps1 - Provisiona VM local (VirtualBox) e sobe a aplicação com Ansible + Docker Compose.

$ErrorActionPreference = "Stop"

$vagrantCmd = Get-Command vagrant -ErrorAction SilentlyContinue
if (-not $vagrantCmd) {
    $fallbackVagrant = "C:\Program Files\Vagrant\bin\vagrant.exe"
    if (Test-Path $fallbackVagrant) {
        $vagrantCmd = @{ Source = $fallbackVagrant }
    }
}
if (-not $vagrantCmd) {
    Write-Error "ERRO: Vagrant não encontrado no PATH e nem em C:\Program Files\Vagrant\bin\vagrant.exe"
    exit 1
}

if (-not (Get-Command ansible-playbook -ErrorAction SilentlyContinue)) {
    Write-Error "ERRO: ansible-playbook não encontrado no PATH."
    exit 1
}

Write-Host "==> Subindo VM" -ForegroundColor Cyan
& $vagrantCmd.Source up

Write-Host "==> Aplicando provisionamento idempotente" -ForegroundColor Cyan
ansible-playbook -i infra/ansible/inventory.ini infra/ansible/playbook.yml

$frontendPort = ((& $vagrantCmd.Source port app 80) | Select-String -Pattern ":" | Select-Object -Last 1).ToString().Split(":")[-1].Trim()
$backendPort = ((& $vagrantCmd.Source port app 3001) | Select-String -Pattern ":" | Select-Object -Last 1).ToString().Split(":")[-1].Trim()
$dbPort = ((& $vagrantCmd.Source port db 5432) | Select-String -Pattern ":" | Select-Object -Last 1).ToString().Split(":")[-1].Trim()

Write-Host ""
Write-Host "Deploy VM concluído" -ForegroundColor Green
Write-Host "Frontend: http://localhost:$frontendPort"
Write-Host "Backend:  http://localhost:$backendPort"
Write-Host "Postgres: localhost:$dbPort (forward para VM de banco:5432)"
