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

$ansibleMode = "native"
if (-not (Get-Command ansible-playbook -ErrorAction SilentlyContinue)) {
    if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
        & wsl.exe ansible-playbook --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            $ansibleMode = "wsl"
        }
    }
}
if ($ansibleMode -eq "native") {
    $ansibleCommand = (Get-Command ansible-playbook -ErrorAction SilentlyContinue)
    if (-not $ansibleCommand) {
        Write-Error "ERRO: Ansible não encontrado. Instale-o no WSL com: sudo apt update; sudo apt install -y ansible"
        exit 1
    }
}

Write-Host "==> Subindo VM" -ForegroundColor Cyan
& $vagrantCmd.Source up

Write-Host "==> Aplicando provisionamento idempotente" -ForegroundColor Cyan
if ($ansibleMode -eq "wsl") {
    & wsl.exe ansible-playbook -i infra/ansible/inventory.ini infra/ansible/playbook.yml
} else {
    & ansible-playbook -i infra/ansible/inventory.ini infra/ansible/playbook.yml
}

$frontendPort = ((& $vagrantCmd.Source port app 80) | Select-String -Pattern ":" | Select-Object -Last 1).ToString().Split(":")[-1].Trim()
$backendPort = ((& $vagrantCmd.Source port app 3001) | Select-String -Pattern ":" | Select-Object -Last 1).ToString().Split(":")[-1].Trim()
$dbPort = ((& $vagrantCmd.Source port db 5432) | Select-String -Pattern ":" | Select-Object -Last 1).ToString().Split(":")[-1].Trim()

Write-Host ""
Write-Host "Deploy VM concluído" -ForegroundColor Green
Write-Host "Frontend: http://localhost:$frontendPort"
Write-Host "Backend:  http://localhost:$backendPort"
Write-Host "Postgres: localhost:$dbPort (forward para VM de banco:5432)"
