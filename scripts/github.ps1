# Envia o projeto ao GitHub para gerar as Fig. 8.2, 8.3, 8.5 e 8.6 no GitHub Actions.
# 1º uso (Fig. 8.2, 8.3 e 8.6):  powershell -ExecutionPolicy Bypass -File .\scripts\github.ps1 -Repositorio https://github.com/SEU_USUARIO/portal-tarefas
# 2º uso (Fig. 8.5, PR com teste quebrado):  ... github.ps1 -Repositorio <mesma URL> -QuebrarTeste
param([Parameter(Mandatory)][string]$Repositorio, [switch]$QuebrarTeste)
. "$PSScriptRoot\_comum.ps1"

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git não encontrado.' }
    $Repositorio = $Repositorio.TrimEnd('/') -replace '\.git$', ''
    Push-Location $Raiz
    try {
        # pipeline com o passo extra de verificação da imagem (evidência das Fig. 8.2 e 8.3)
        $semBom = New-Object System.Text.UTF8Encoding $false
        New-Item -ItemType Directory -Force (Join-Path $Raiz '.github\workflows') | Out-Null
        $ci = @'
name: ci

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.0.x'
      - run: dotnet restore
      - run: dotnet build --no-restore -c Release
      - run: dotnet test --no-build -c Release --filter "Category!=Integracao"
      - run: dotnet list package --include-transitive > inventario-dependencias.txt
      - uses: actions/upload-artifact@v4
        with:
          name: inventario-dependencias
          path: inventario-dependencias.txt

  frontend:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: PortalTarefas.Frontend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '24'
          cache: npm
          cache-dependency-path: PortalTarefas.Frontend/package-lock.json
      - run: npm ci
      - run: npm test --if-present
      - run: npm run build

  imagem:
    needs: [backend, frontend]          # gate: só roda se os dois jobs passarem
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      - name: Build da imagem (tag = commit)
        run: |
          IMAGE="ghcr.io/${GITHUB_REPOSITORY,,}:${GITHUB_SHA}"
          echo "IMAGE=$IMAGE" >> "$GITHUB_ENV"
          docker build --label org.opencontainers.image.revision="$GITHUB_SHA" -t "$IMAGE" .
      - name: Smoke test (liveness)
        run: |
          docker run -d --name smoke -p 8080:8080 -e ConnectionStrings__DefaultConnection="Server=ci-sem-banco" "$IMAGE"
          curl --retry 20 --retry-delay 2 --retry-all-errors -fsS http://localhost:8080/health/live || { docker logs smoke; exit 1; }
      - name: Segredos na imagem (docker history e docker inspect)
        run: |
          echo "== docker images =="
          docker images "$IMAGE"
          echo "== docker history: procura por segredos nas camadas =="
          if docker history --no-trunc --format '{{.CreatedBy}}' "$IMAGE" | grep -Ei 'password|senha|connectionstrings__'; then exit 1; else echo "nenhum segredo encontrado nas camadas"; fi
          echo "== docker image inspect: variaveis gravadas na imagem =="
          docker image inspect --format '{{json .Config.Env}}' "$IMAGE"
          echo "== usuario do conteiner (nao root) =="
          docker exec smoke id
          echo "== curl -i http://localhost:8080/health/live =="
          curl -s -i http://localhost:8080/health/live
          echo
          docker ps --filter name=smoke
      - name: Publicar no GHCR
        run: |
          echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u "${{ github.actor }}" --password-stdin
          docker push "$IMAGE"
'@
        [IO.File]::WriteAllText((Join-Path $Raiz '.github\workflows\ci.yml'), ($ci -replace "`r`n", "`n") + "`n", $semBom)

        if (-not (Test-Path '.git')) { & git init -q -b main }
        & git checkout -q main 2>$null
        & git -c core.autocrlf=false add -A *> $null
        & git -c core.autocrlf=false -c user.name='Jonathas da Silva Nunes' -c user.email='jonathas@portal.local' commit -q -m 'CI: verificação de segredos na imagem' *> $null
        if ((& git remote) -contains 'origin') { & git remote set-url origin "$Repositorio.git" } else { & git remote add origin "$Repositorio.git" }

        if (-not $QuebrarTeste) {
            Passo 'Enviando a main (pode abrir uma janela de login do GitHub)'
            & git push -u origin main
            if ($LASTEXITCODE -ne 0) { throw 'O push falhou. Confira se o repositório existe e se você entrou na conta do GitHub.' }
            Ok "Enviado. Acompanhe em: $Repositorio/actions"
            Write-Host 'Quando a execução da main ficar verde:' -ForegroundColor Cyan
            Write-Host '  Fig. 8.6 = tela do resumo da execução (jobs backend, frontend e imagem + artefato inventario-dependencias)'
            Write-Host '  Fig. 8.2 = job imagem aberto no passo "Segredos na imagem (docker history e docker inspect)"'
            Write-Host '  Fig. 8.3 = mesmo passo, rolado até "curl -i http://localhost:8080/health/live" (200 Healthy)'
        } else {
            Passo 'Criando a branch teste-quebrado com um teste quebrado de propósito'
            & git checkout -q -B teste-quebrado
            $arq = Join-Path $Raiz 'PortalTarefas.Tests\TarefasTests.cs'
            $t = Get-Content $arq -Raw -Encoding UTF8
            $t = $t.Replace('=> Assert.Empty(Validar(new TarefaInputModel { Titulo = "x", Prazo = DateTime.Today.AddDays(2) }));',
                            '=> Assert.NotEmpty(Validar(new TarefaInputModel { Titulo = "x", Prazo = DateTime.Today.AddDays(2) }));   // quebrado de propósito')
            [IO.File]::WriteAllText($arq, $t, (New-Object System.Text.UTF8Encoding $true))
            & git -c core.autocrlf=false -c user.name='Jonathas da Silva Nunes' -c user.email='jonathas@portal.local' commit -q -am 'Teste quebrado de propósito (demonstração do gate de CI)' *> $null
            & git push -u origin teste-quebrado
            & git checkout -q main
            Ok 'Branch enviada. Abra o Pull Request neste link e clique em "Create pull request":'
            Write-Host "  $Repositorio/compare/main...teste-quebrado?expand=1" -ForegroundColor Cyan
            Write-Host '  Fig. 8.5 = aba Checks do PR: job backend com X vermelho e job imagem sem executar. Depois feche o PR sem merge.'
        }
    } finally { Pop-Location }
}
catch { Write-Host "`nERRO: $($_.Exception.Message)" -ForegroundColor Red }
