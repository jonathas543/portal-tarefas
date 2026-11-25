# Coleta as versões do ambiente para a tabela "Ambiente" do relatório -> evidencias\ambiente.txt
. "$PSScriptRoot\_comum.ps1"
$saida = Join-Path $Evid 'ambiente.txt'
$l = New-Object System.Collections.Generic.List[string]
function Add([string]$t) { $l.Add($t); Write-Host $t }

Add "Data: $(Get-Date -Format 'dd/MM/yyyy HH:mm')   Máquina: $env:COMPUTERNAME"
Add "SO: $((Get-CimInstance Win32_OperatingSystem).Caption) $((Get-CimInstance Win32_OperatingSystem).Version)"
Add "dotnet --version: $(& dotnet --version)"
Add "SDKs instalados:"; & dotnet --list-sdks | ForEach-Object { Add "  $_" }
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) { & $vswhere -all -prerelease -format json | ConvertFrom-Json | ForEach-Object { Add "Visual Studio: $($_.displayName) $($_.catalog.productDisplayVersion)" } }
else { Add 'Visual Studio: não encontrado (vswhere ausente)' }
try { Add ("VS Code: " + ((& code --version) | Select-Object -First 1)) } catch {}
try { $v = (Sql "SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar(30)) AS v, CAST(SERVERPROPERTY('Edition') AS varchar(80)) AS e, CAST(SERVERPROPERTY('ProductLevel') AS varchar(10)) AS n" $CsMaster).Rows[0]
      Add "SQL Server: $($v.v) $($v.e) $($v.n)" } catch { Add "SQL Server: $($_.Exception.Message)" }
try { Add "Node: $(& node -v)   npm: $(& npm.cmd -v)" } catch {}
if (Test-Path (Join-Path $Front 'node_modules')) {
    Push-Location $Front; Add 'Pacotes do front-end (npm ls --depth=0):'; & npm.cmd ls --depth=0 2>$null | ForEach-Object { Add "  $_" }; Pop-Location
}
try { Add "Docker: $(& docker --version)" } catch { Add 'Docker: não instalado' }
try { Add "Git: $(& git --version)" } catch {}
Add 'Pacotes NuGet (versões resolvidas):'
& dotnet list (Join-Path $Raiz 'PortalTarefas.sln') package 2>$null | Where-Object { $_ -match '>' -or $_ -match 'Project' } | ForEach-Object { Add "  $_" }
$l | Set-Content $saida -Encoding UTF8
Write-Host "`nSalvo em evidencias\ambiente.txt" -ForegroundColor Green
