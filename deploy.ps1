# deploy.ps1 - Provisiona as VMs e sobe a aplicação com Vagrant + Docker Compose.

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

Write-Host "==> Criando/iniciando as VMs" -ForegroundColor Cyan
& $vagrantCmd.Source up app --no-provision
& $vagrantCmd.Source up db --no-provision

Write-Host "==> Provisionando a VM do banco" -ForegroundColor Cyan
& $vagrantCmd.Source provision db
if ($LASTEXITCODE -ne 0) { throw "O provisionamento da VM db falhou com código $LASTEXITCODE." }

Write-Host "==> Provisionando a VM da aplicação" -ForegroundColor Cyan
& $vagrantCmd.Source provision app
if ($LASTEXITCODE -ne 0) { throw "O provisionamento da VM app falhou com código $LASTEXITCODE." }

function Get-ForwardedPort([string]$machine, [int]$guestPort) {
    $line = & $vagrantCmd.Source port $machine | Select-String -Pattern "^\s*$guestPort\s+\(guest\)\s+=>" | Select-Object -Last 1
    if (-not $line) { throw "Não foi possível descobrir a porta encaminhada $guestPort da VM $machine." }
    return [int]([regex]::Match($line.ToString(), "=>\s*(\d+)").Groups[1].Value)
}

$frontendPort = Get-ForwardedPort "app" 80
$backendPort = Get-ForwardedPort "app" 3001
$dbPort = Get-ForwardedPort "db" 5432

Write-Host ""
Write-Host "Deploy VM concluído" -ForegroundColor Green
Write-Host "Frontend: http://localhost:$frontendPort"
Write-Host "Backend:  http://localhost:$backendPort"
Write-Host "Postgres: localhost:$dbPort (forward para VM de banco:5432)"
