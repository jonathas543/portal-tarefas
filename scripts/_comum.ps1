# Funções compartilhadas pelos scripts de evidências (r3.ps1 ... r8.ps1)
# Compatível com Windows PowerShell 5.1 e PowerShell 7.

# 'Continue': no Windows PowerShell 5.1, 'Stop' + saída de erro de programas nativos interrompe o script.
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$Raiz        = Split-Path -Parent $PSScriptRoot
$Web         = Join-Path $Raiz 'PortalTarefas.Web'
$Front       = Join-Path $Raiz 'PortalTarefas.Frontend'
$Evid        = Join-Path $Raiz 'evidencias'
$Tmp         = Join-Path $Evid '_tmp'
$ApiHttps    = 'https://localhost:7000'
$Banco       = 'PortalTarefas'
$ServidorSql = 'localhost'
$CsBanco     = "Server=$ServidorSql;Database=$Banco;Trusted_Connection=True;TrustServerCertificate=True"
$CsMaster    = "Server=$ServidorSql;Database=master;Trusted_Connection=True;TrustServerCertificate=True"
$SeedId      = '7f3c1d52-0a6b-4a5e-9a52-3f1d6a0c1b01'

New-Item -ItemType Directory -Force $Evid, $Tmp | Out-Null

# ---------------------------------------------------------------- captura de tela
Add-Type -AssemblyName System.Drawing
if (-not ('JanelaCaptura' -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class JanelaCaptura {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT r, int size);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
}
"@
}
[void][JanelaCaptura]::SetProcessDPIAware()

function Capturar([string]$Nome) {
    # Captura a janela do VS Code (onde o script roda) mesmo que outra janela esteja na frente.
    Start-Sleep -Milliseconds 900
    $arq = Join-Path $Evid "$Nome.png"
    $code = Get-Process Code -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -like '*Visual Studio Code*' -and -not [JanelaCaptura]::IsIconic($_.MainWindowHandle) } |
            Sort-Object { if ($_.MainWindowTitle -like '*codigo-relatorio1*') { 0 } else { 1 } } | Select-Object -First 1
    if ($code) {
        $h = $code.MainWindowHandle
        $r = New-Object JanelaCaptura+RECT
        [void][JanelaCaptura]::GetWindowRect($h, [ref]$r)
        $w = $r.Right - $r.Left; $a = $r.Bottom - $r.Top
        $bmp = New-Object System.Drawing.Bitmap $w, $a
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $hdc = $g.GetHdc(); $ok = [JanelaCaptura]::PrintWindow($h, $hdc, 2); $g.ReleaseHdc($hdc)
        # confere se a imagem tem conteúdo (algumas placas de vídeo devolvem a janela toda preta)
        $cores = @{}; foreach ($k in 1..40) { $cores[$bmp.GetPixel([int]($w * $k / 41), [int]($a * (($k * 7) % 41) / 41)).ToArgb()] = 1 }
        if ($ok -and $cores.Count -gt 2) {
            $v = New-Object JanelaCaptura+RECT
            if ([JanelaCaptura]::DwmGetWindowAttribute($h, 9, [ref]$v, 16) -eq 0) {
                $rect = New-Object System.Drawing.Rectangle ($v.Left - $r.Left), ($v.Top - $r.Top), ($v.Right - $v.Left), ($v.Bottom - $v.Top)
                $rect.Intersect((New-Object System.Drawing.Rectangle 0, 0, $w, $a))
                $final = $bmp.Clone($rect, $bmp.PixelFormat); $final.Save($arq, [System.Drawing.Imaging.ImageFormat]::Png); $final.Dispose()
            } else { $bmp.Save($arq, [System.Drawing.Imaging.ImageFormat]::Png) }
            $g.Dispose(); $bmp.Dispose()
            Write-Host "  [print salvo: evidencias\$Nome.png]" -ForegroundColor DarkGray
            return
        }
        $g.Dispose(); $bmp.Dispose()
    }
    # alternativa: janela em primeiro plano
    $h = [JanelaCaptura]::GetForegroundWindow()
    $r = New-Object JanelaCaptura+RECT
    if ([JanelaCaptura]::DwmGetWindowAttribute($h, 9, [ref]$r, 16) -ne 0) { [void][JanelaCaptura]::GetWindowRect($h, [ref]$r) }
    $l = [Math]::Max(0, $r.Left); $t = [Math]::Max(0, $r.Top)
    $w = $r.Right - $l; $a = $r.Bottom - $t
    if ($w -lt 100 -or $a -lt 100) { Write-Warning "Janela inválida para captura ($Nome)."; return }
    $bmp = New-Object System.Drawing.Bitmap $w, $a
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($l, $t, 0, 0, $bmp.Size)
    $bmp.Save($arq, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Host "  [print salvo (janela em primeiro plano): evidencias\$Nome.png]" -ForegroundColor DarkYellow
}

function Figura([string]$Nome, [string]$Titulo) {
    Clear-Host
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host " $($Nome -replace '_', ' ' -replace 'Fig ', 'Fig. ' -replace ' (\d+) (\d+)', ' $1.$2') - $Titulo" -ForegroundColor Cyan
    Write-Host (" Portal de Tarefas | " + (Get-Date -Format 'dd/MM/yyyy HH:mm:ss') + " | " + $env:COMPUTERNAME) -ForegroundColor DarkCyan
    Write-Host ("=" * 100) -ForegroundColor Cyan
}

function Passo([string]$Texto) { Write-Host ""; Write-Host "> $Texto" -ForegroundColor Yellow }
function Ok([string]$Texto)    { Write-Host "  OK: $Texto" -ForegroundColor Green }

# Captura assistida: para telas do navegador. O aluno prepara a tela, pressiona Enter
# e tem alguns segundos para deixar o navegador em primeiro plano.
function CapturaAssistida([string]$Nome, [string]$Instrucao, [int]$Segundos = 6) {
    Write-Host ""
    Write-Host ("-" * 100) -ForegroundColor Magenta
    Write-Host " $Nome" -ForegroundColor Magenta
    Write-Host " $Instrucao" -ForegroundColor White
    Write-Host ("-" * 100) -ForegroundColor Magenta
    $r = Read-Host " Pressione Enter e, em seguida, clique na janela do navegador (ou digite P para pular)"
    if ($r -match '^[Pp]') { Write-Host "  (pulado)"; return }
    for ($i = $Segundos; $i -gt 0; $i--) { Write-Host -NoNewline " $i..."; Start-Sleep 1 }
    Write-Host ""
    Capturar $Nome
    # devolve o foco ao VS Code: os prints seguintes são tirados da janela em primeiro plano
    [void](Read-Host ' Print salvo. Clique de volta no terminal do VS Code e pressione Enter para continuar')
}

# ---------------------------------------------------------------- execução de comandos
function Executar([string]$Exe, [string[]]$Argumentos, [int]$UltimasLinhas = 0, [switch]$PermitirFalha) {
    Write-Host "PS> $Exe $($Argumentos -join ' ')" -ForegroundColor Gray
    $saida = & $Exe @Argumentos 2>&1 | ForEach-Object { "$_" }
    $codigo = $LASTEXITCODE
    if ($UltimasLinhas -gt 0) { $saida | Select-Object -Last $UltimasLinhas | Write-Host } else { $saida | Write-Host }
    if ($codigo -ne 0 -and -not $PermitirFalha) {
        $saida | Set-Content (Join-Path $Tmp 'ultimo-erro.txt') -Encoding UTF8
        throw "Falhou: $Exe $($Argumentos -join ' ') (código $codigo). Saída completa em evidencias\_tmp\ultimo-erro.txt"
    }
    return $codigo
}

function Compilar {
    Parar-Api
    Passo 'Compilando a solução'
    $saida = & dotnet build (Join-Path $Raiz 'PortalTarefas.sln') -nologo -v q '-clp:NoSummary;ErrorsOnly' 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) {
        $saida | Set-Content (Join-Path $Tmp 'ultimo-erro.txt') -Encoding UTF8
        $saida | Select-Object -Last 30 | Write-Host
        throw 'O build falhou. Saída completa em evidencias\_tmp\ultimo-erro.txt'
    }
    Ok 'dotnet build: compilação concluída sem erros'
}

# ---------------------------------------------------------------- fases de código
function Aplicar-Fase([string]$Fase) {
    $origem = Join-Path $Raiz "fases\$Fase"
    if (-not (Test-Path $origem)) { throw "Pasta da fase não encontrada: $origem" }
    Get-ChildItem $origem -Recurse -File -Force | ForEach-Object {
        $rel = $_.FullName.Substring($origem.Length).TrimStart('\')
        $dest = Join-Path $Raiz $rel
        New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
        Copy-Item $_.FullName $dest -Force
        # Copy-Item preserva a data original; sem atualizar, o MSBuild acharia que o build está em dia
        (Get-Item $dest -Force).LastWriteTime = Get-Date
    }
    Set-Content (Join-Path $Raiz ".fase-$Fase") (Get-Date -Format o)
    Ok "Código da fase $Fase aplicado ao projeto"
}

function Exigir-Fase([string]$Fase) {
    if (-not (Test-Path (Join-Path $Raiz ".fase-$Fase"))) { throw "Rode antes o script $Fase.ps1 (a fase $Fase ainda não foi aplicada)." }
}

# ---------------------------------------------------------------- segredos de desenvolvimento
function Senhas-Dev {
    $arq = Join-Path $PSScriptRoot '.senhas-dev.ps1'
    if (-not (Test-Path $arq)) {
        function Nova { 'Pt#' + ([guid]::NewGuid().ToString('N').Substring(0, 10)) + 'Z9' }
        "`$SenhaAdmin = '$(Nova)'`n`$SenhaUsuario = '$(Nova)'" | Set-Content $arq -Encoding UTF8
    }
    . $arq
    return @{ Admin = $SenhaAdmin; Usuario = $SenhaUsuario }
}

function Configurar-Segredos {
    $s = Senhas-Dev
    $p = @('--project', $Web)
    & dotnet user-secrets set 'ConnectionStrings:DefaultConnection' $CsBanco @p | Out-Null
    & dotnet user-secrets set 'Seed:AdminSenha' $s.Admin @p | Out-Null
    & dotnet user-secrets set 'Seed:UsuarioSenha' $s.Usuario @p | Out-Null
    Ok 'User Secrets configurados (connection string e senhas de seed fora do repositório)'
}

# ---------------------------------------------------------------- SQL Server
function Sql([string]$Comando, [string]$Cs = $CsBanco) {
    $con = New-Object System.Data.SqlClient.SqlConnection $Cs
    try {
        $con.Open()
        $cmd = $con.CreateCommand(); $cmd.CommandText = $Comando; $cmd.CommandTimeout = 60
        $tab = New-Object System.Data.DataTable
        $leitor = $cmd.ExecuteReader(); $tab.Load($leitor)
        return ,$tab
    } finally { $con.Dispose() }
}

function MostrarSql([string]$Titulo, [string]$Comando) {
    Write-Host "SQL> $Titulo" -ForegroundColor Gray
    $t = Sql $Comando
    if ($t.Rows.Count -eq 0) { Write-Host '  (nenhuma linha)'; return }
    $colunas = @($t.Columns | ForEach-Object { $_.ColumnName })
    ($t.Rows | Select-Object $colunas | Format-Table -AutoSize | Out-String -Width 220).TrimEnd() | Write-Host
}

function Banco-Existe { (Sql "SELECT COUNT(*) AS n FROM sys.databases WHERE name = '$Banco'" $CsMaster).Rows[0].n -gt 0 }

function Excluir-Banco {
    if (Banco-Existe) {
        [void](Sql "ALTER DATABASE [$Banco] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$Banco];" $CsMaster)
    }
}

# ---------------------------------------------------------------- API em segundo plano
$script:ApiProc = $null
$script:ApiLog = $null

function Iniciar-Api([hashtable]$Ambiente = @{}, [string]$NomeLog = 'api') {
    Parar-Api
    $exe = Join-Path $Web 'bin\Debug\net10.0\PortalTarefas.Web.exe'
    if (-not (Test-Path $exe)) { throw "Executável não encontrado. Compile a solução antes." }
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    $env:ASPNETCORE_URLS = 'https://localhost:7000;http://localhost:5000'
    foreach ($k in $Ambiente.Keys) { Set-Item "env:$k" $Ambiente[$k] }
    $script:ApiLog = Join-Path $Tmp "$NomeLog.log"
    $script:ApiProc = Start-Process -FilePath $exe -WorkingDirectory $Web -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $script:ApiLog -RedirectStandardError (Join-Path $Tmp "$NomeLog.err.log")
    foreach ($k in $Ambiente.Keys) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Milliseconds 700
        if ($script:ApiProc.HasExited) { break }
        $c = & curl.exe -k -s -o NUL -w '%{http_code}' "$ApiHttps/api/diagnostico/ping"
        if ($c -eq '200') { Ok "API em execução em $ApiHttps (log: evidencias\_tmp\$NomeLog.log)"; return }
    }
    Get-Content (Join-Path $Tmp "$NomeLog.err.log") -ErrorAction SilentlyContinue | Select-Object -Last 30 | Write-Host
    Get-Content $script:ApiLog -ErrorAction SilentlyContinue | Select-Object -Last 30 | Write-Host
    throw 'A API não respondeu em /api/diagnostico/ping. Veja os logs acima.'
}

function Parar-Api {
    if ($script:ApiProc -and -not $script:ApiProc.HasExited) {
        Stop-Process -Id $script:ApiProc.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800
    }
    Get-Process PortalTarefas.Web -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    $script:ApiProc = $null
}

function LogApi { if ($script:ApiLog -and (Test-Path $script:ApiLog)) { Get-Content $script:ApiLog -Encoding UTF8 } else { @() } }

# ---------------------------------------------------------------- HTTP (curl.exe)
# Mostra a requisição, a linha de status, cabeçalhos selecionados e o corpo (JSON indentado e truncado).
function Http {
    param(
        [string]$Metodo = 'GET', [string]$Url, [string]$Corpo = $null, [string]$CorpoExibido = $null,
        [string]$Cookies = $null, [string]$SalvarCookies = $null,
        [string[]]$Cabecalhos = @(), [string[]]$MostrarCabecalhos = @('Location', 'X-Total-Count', 'Set-Cookie', 'Retry-After', 'Access-Control-Allow-Origin'),
        [int]$MaxLinhas = 14, [switch]$Silencioso
    )
    if ($Url -notmatch '^https?://') { $Url = "$ApiHttps$Url" }
    $a = @('-k', '-s', '-i', '-X', $Metodo, $Url)
    foreach ($c in $Cabecalhos) { $a += @('-H', $c) }
    if ($Corpo) {
        $arq = Join-Path $Tmp 'corpo.json'
        [IO.File]::WriteAllText($arq, $Corpo, (New-Object System.Text.UTF8Encoding $false))
        $a += @('-H', 'Content-Type: application/json', '--data-binary', "@$arq")
    }
    if ($Cookies) { $a += @('-b', $Cookies) }
    if ($SalvarCookies) { $a += @('-c', $SalvarCookies) }
    $bruto = (& curl.exe @a) -join "`n"
    $partes = $bruto -split "`n\r?`n", 2
    $cab = $partes[0] -split "`n"
    $corpoResp = if ($partes.Count -gt 1) { $partes[1].Trim() } else { '' }
    $status = ($cab[0] -split ' ')[1]
    $res = [pscustomobject]@{ Status = [int]$status; Corpo = $corpoResp; Cabecalhos = $cab; Json = $null }
    try { if ($corpoResp.StartsWith('{') -or $corpoResp.StartsWith('[')) { $res.Json = $corpoResp | ConvertFrom-Json } } catch {}
    if ($Silencioso) { return $res }

    $exibir = $Url.Replace($ApiHttps, '')
    Write-Host "$Metodo $exibir" -ForegroundColor White -NoNewline
    if ($CorpoExibido) { Write-Host "  corpo: $CorpoExibido" -ForegroundColor DarkGray }
    elseif ($Corpo) { Write-Host "  corpo: $Corpo" -ForegroundColor DarkGray } else { Write-Host '' }
    $cor = if ($res.Status -lt 300) { 'Green' } elseif ($res.Status -lt 500) { 'Yellow' } else { 'Red' }
    Write-Host ("  " + $cab[0].Trim()) -ForegroundColor $cor
    foreach ($h in $cab | Select-Object -Skip 1) {
        foreach ($m in $MostrarCabecalhos) { if ($h -like "${m}:*") { Write-Host ("  " + $h.Trim()) -ForegroundColor DarkYellow } }
    }
    if ($corpoResp) {
        $texto = if ($res.Json) { $res.Json | ConvertTo-Json -Depth 6 -Compress:$false } else { $corpoResp }
        $linhas = $texto -split "`r?`n"
        $linhas | Select-Object -First $MaxLinhas | ForEach-Object { Write-Host "  $_" }
        if ($linhas.Count -gt $MaxLinhas) { Write-Host "  ... ($($linhas.Count - $MaxLinhas) linhas omitidas)" -ForegroundColor DarkGray }
    }
    return $res
}

function StatusHttp([string]$Metodo, [string]$Url, [string]$Cookies = $null, [string]$Corpo = $null) {
    (Http -Metodo $Metodo -Url $Url -Cookies $Cookies -Corpo $Corpo -Silencioso).Status
}

function Login([string]$Email, [string]$Senha, [string]$Jar) {
    if (Test-Path $Jar) { Remove-Item $Jar -Force }
    $corpo = (@{ email = $Email; senha = $Senha } | ConvertTo-Json -Compress)
    return Http -Metodo POST -Url '/api/conta/login' -Corpo $corpo -SalvarCookies $Jar -Silencioso
}

# ---------------------------------------------------------------- pré-requisitos
function Verificar-Ferramentas([switch]$Node, [switch]$Ef) {
    Passo 'Verificando ferramentas'
    $v = & dotnet --version; Ok ".NET SDK $v"
    & dotnet dev-certs https --check --trust *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host '  Confiando no certificado HTTPS de desenvolvimento (o Windows pode pedir confirmação)...' -ForegroundColor Yellow
        & dotnet dev-certs https --trust | Out-Null
    }
    Ok 'Certificado HTTPS de desenvolvimento confiável'
    if ($Ef) {
        $env:PATH = "$env:PATH;$env:USERPROFILE\.dotnet\tools"
        & dotnet ef --version *> $null
        if ($LASTEXITCODE -ne 0) {
            Write-Host '  Instalando a ferramenta dotnet-ef (linha 10)...' -ForegroundColor Yellow
            & dotnet tool install --global dotnet-ef --version '10.*' | Out-Null
            if ($LASTEXITCODE -ne 0) { & dotnet tool install --global dotnet-ef | Out-Null }
        }
        Ok ("dotnet-ef " + ((& dotnet ef --version) | Select-Object -Last 1))
    }
    if ($Node) { Ok ("Node " + (& node -v) + " / npm " + (& npm.cmd -v)) }
    try { [void](Sql 'SELECT 1 AS ok' $CsMaster); Ok "SQL Server acessível em $ServidorSql" }
    catch { throw "Não foi possível conectar ao SQL Server em $ServidorSql com autenticação do Windows: $($_.Exception.Message)" }
}
