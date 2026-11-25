# Evidências dos Relatórios 3 a 8 – como rodar

Os scripts aplicam o código de cada relatório (pasta `fases`), compilam, sobem a API, executam os cenários das tabelas de testes e **salvam os prints sozinhos** em `evidencias\Fig_X_Y.png`.

## Antes de começar
1. Abra a pasta `codigo-relatorio1` no VS Code e abra o terminal (Ctrl + ').
2. **Maximize o painel do terminal** (botão ^ no canto do painel). O print é tirado da janela do VS Code.
3. Durante cada script, **não troque de janela**, a não ser quando o script pedir (telas do navegador).
4. O SQL Server precisa estar ligado (`localhost`, autenticação do Windows).

## Ordem (um comando por vez, no terminal do VS Code)
```
powershell -ExecutionPolicy Bypass -File .\scripts\r3.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\r4.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\r5.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\r6.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\r7.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\r8.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\ambiente.ps1
```
Se algum script mostrar **ERRO**, pare e mande a mensagem (e `evidencias\_tmp\ultimo-erro.txt`) para o Claude.

## Telas do navegador (r4, r5 e r6)
O script mostra a instrução, você prepara a tela, aperta **Enter** e **clica no navegador** durante a contagem de 6 s. O print é salvo com o nome certo. Digite **P** para pular uma tela.

## Fig. 8.5 e 8.6 (GitHub Actions) – manuais
1. Crie um repositório no GitHub e envie o projeto (`git remote add origin ...` e `git push -u origin main`). O `r8.ps1` já fez o primeiro commit.
2. **Fig. 8.6:** na aba *Actions*, abra a execução da `main` (verde): print com os jobs backend, frontend e imagem e o artefato *inventario-dependencias*.
3. **Fig. 8.5:** crie uma branch, quebre um teste de propósito (ex.: troque `Assert.Empty` por `Assert.NotEmpty` em `Modelo_valido_nao_gera_erros`), faça push e abra um Pull Request: print com o job backend falhando e o job imagem sem executar. Depois feche o PR sem fazer merge.

## Senhas de desenvolvimento
Ficam em User Secrets e em `scripts\.senhas-dev.ps1` (ignorado pelo Git). Elas aparecem só na tela do r6, antes das telas de login, e nunca nos prints.

## Arquivo .env.example (criar à mão)
A ferramenta remota não pode gravar arquivos `.env*`. Crie na raiz da solução o arquivo `.env.example` com:
```
# .env.example – copie para .env e preencha localmente (NUNCA versionar o .env)
ConnectionStrings__DefaultConnection=
MSSQL_SA_PASSWORD=
Dependencias__Url=http://localhost:8080
Seed__AdminSenha=
Seed__UsuarioSenha=
```
