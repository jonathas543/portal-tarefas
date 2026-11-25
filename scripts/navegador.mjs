// Automação do navegador (Playwright + Google Chrome instalado; Edge como alternativa) para as telas dos Relatórios 5 e 6.
// Uso: node scripts/navegador.mjs <cenario>     cenarios: r5 | r5-erro | r6
// Os prints da janela do Edge (com a barra de endereço) são feitos por capturar-janela.ps1.
import { createRequire } from 'node:module';
import { spawnSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const dirScripts = path.dirname(fileURLToPath(import.meta.url));
const raiz = path.dirname(dirScripts);
const evid = path.join(raiz, 'evidencias');
const require = createRequire(path.join(dirScripts, '.nav', 'package.json'));
const { chromium } = require('playwright-core');

const BASE = 'http://localhost:5173';
const SEED1 = '7f3c1d52-0a6b-4a5e-9a52-3f1d6a0c1b01';
const SEED3 = '7f3c1d52-0a6b-4a5e-9a52-3f1d6a0c1b03';
const espera = (ms) => new Promise((r) => setTimeout(r, ms));

function capturar(nome) {
  const r = spawnSync('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
    path.join(dirScripts, 'capturar-janela.ps1'), '-Nome', nome], { stdio: 'inherit' });
  if (r.status !== 0) console.log(`  (falha ao capturar ${nome})`);
}

async function abrir() {
  let navegador;
  try { navegador = await chromium.launch({ channel: 'chrome', headless: false, args: ['--start-maximized'] }); }
  catch { navegador = await chromium.launch({ channel: 'msedge', headless: false, args: ['--start-maximized'] }); }
  const contexto = await navegador.newContext({ viewport: null, locale: 'pt-BR', ignoreHTTPSErrors: true });
  const pagina = await contexto.newPage();
  return { navegador, contexto, pagina };
}

async function print(pagina, nome, descricao) {
  console.log(`> ${nome}: ${descricao}`);
  await pagina.bringToFront();
  await espera(900);
  capturar(nome);
}

async function cenarioR5() {
  const { navegador, pagina } = await abrir();
  try {
    // 5.1a – mensagem de carregamento (resposta da API atrasada em 3 s apenas nesta etapa)
    await pagina.route('**/api/tarefas?**', async (rota) => { await espera(3000); await rota.continue().catch(() => {}); });
    await pagina.goto(`${BASE}/tarefas`);
    await pagina.getByText('Carregando…').waitFor();
    await print(pagina, 'Fig_5_1a', 'lista em carregamento');
    await pagina.unroute('**/api/tarefas?**');

    // 5.1 – lista carregada
    await pagina.goto(`${BASE}/tarefas`);
    await pagina.locator('ul li').first().waitFor();
    await print(pagina, 'Fig_5_1', 'lista de tarefas');

    // 5.1b – nenhuma tarefa
    await pagina.goto(`${BASE}/tarefas?busca=nao-existe-xyz`);
    await pagina.getByText('Nenhuma tarefa encontrada.').waitFor();
    await print(pagina, 'Fig_5_1b', 'lista vazia');

    // 5.2b – erro 400 vindo do Problem Details
    await pagina.goto(`${BASE}/tarefas?ordenarPor=id`);
    await pagina.getByRole('alert').waitFor();
    await print(pagina, 'Fig_5_2b', 'erro 400 (Problem Details)');

    // 5.3 – acesso direto aos detalhes / 5.3b – id inexistente
    await pagina.goto(`${BASE}/tarefas/${SEED3}`);
    await pagina.locator('article h1').waitFor();
    await print(pagina, 'Fig_5_3', 'detalhes por acesso direto à URL');
    await pagina.goto(`${BASE}/tarefas/00000000-0000-0000-0000-000000000001`);
    await pagina.getByText('Tarefa não encontrada.').waitFor();
    await print(pagina, 'Fig_5_3b', 'tarefa inexistente (404)');

    // 5.4 – filtro na URL e recarga mantendo o estado
    await pagina.goto(`${BASE}/tarefas`);
    await pagina.locator('ul li').first().waitFor();
    await pagina.locator('select').selectOption('Pendente');
    await pagina.waitForURL(/situacao=Pendente/);
    await pagina.reload();
    await pagina.locator('ul li').first().waitFor();
    await print(pagina, 'Fig_5_4', 'filtro e página na URL após recarregar');

    // 5.5 – cadastro inválido / 5.5b – cadastro válido
    await pagina.goto(`${BASE}/tarefas/nova`);
    await pagina.getByRole('button', { name: 'Salvar' }).click();
    await pagina.getByRole('alert').first().waitFor();
    await print(pagina, 'Fig_5_5', 'cadastro inválido: erros por campo');
    await pagina.locator('label:has-text("Título") input').fill('Revisar o relatório final');
    await pagina.locator('textarea').fill('Criada pela SPA, sem recarregar a página.');
    await pagina.locator('input[type=date]').fill('2026-12-18');
    await pagina.getByRole('button', { name: 'Salvar' }).click();
    await pagina.waitForURL(/\/tarefas\/[0-9a-f-]{36}$/);
    await pagina.locator('article h1').waitFor();
    await print(pagina, 'Fig_5_5b', 'cadastro válido: detalhes sem recarregar');

    // 5.6 – troca rápida de filtro com atraso simulado: a requisição anterior é cancelada
    const rede = [];
    pagina.on('request', (q) => { if (q.url().includes('/api/tarefas?')) rede.push({ t: Date.now(), ev: 'enviada  ', url: q.url() }); });
    pagina.on('requestfailed', (q) => { if (q.url().includes('/api/tarefas?')) rede.push({ t: Date.now(), ev: 'CANCELADA', url: q.url(), erro: q.failure()?.errorText }); });
    pagina.on('requestfinished', async (q) => { if (q.url().includes('/api/tarefas?')) { const r = await q.response(); rede.push({ t: Date.now(), ev: 'concluída', url: q.url(), status: r?.status() }); } });
    await pagina.goto(`${BASE}/tarefas`);
    await pagina.locator('ul li').first().waitFor();
    rede.length = 0;
    await pagina.route('**/api/tarefas?**', async (rota) => { await espera(2000); await rota.continue().catch(() => {}); });
    const inicio = Date.now();
    await pagina.locator('select').selectOption('Pendente');
    await espera(300);
    await pagina.locator('select').selectOption('EmAndamento');
    await espera(3500);
    await print(pagina, 'Fig_5_6b', 'resultado após a troca rápida de filtro');
    const linhas = rede.map((e) => `${String(e.t - inicio).padStart(5)} ms  ${e.ev}  ${e.url.replace(BASE, '')}` +
      (e.status ? `  HTTP ${e.status}` : '') + (e.erro ? `  (${e.erro})` : ''));
    writeFileSync(path.join(evid, '_tmp', 'rede-5_6.txt'), linhas.join('\n'), 'utf8');
  } finally { await navegador.close(); }
}

async function cenarioR5Erro() {
  const { navegador, pagina } = await abrir();
  try {
    await pagina.goto(`${BASE}/tarefas`);
    await pagina.getByRole('alert').waitFor({ timeout: 15000 });
    await print(pagina, 'Fig_5_2', 'API parada: erro de rede, sem ficar em carregamento');
  } finally { await navegador.close(); }
}

async function entrar(pagina, email, senha) {
  await pagina.locator('input[type=email]').fill(email);
  await pagina.locator('input[type=password]').fill(senha);
  await pagina.getByRole('button', { name: 'Entrar' }).click();
}

async function cenarioR6() {
  const usuario = process.env.PT_SENHA_USUARIO, admin = process.env.PT_SENHA_ADMIN;
  const { navegador, contexto, pagina } = await abrir();
  try {
    // 6.5 – rota protegida sem sessão vai ao login e, depois de entrar, volta à URL pretendida
    await pagina.goto(`${BASE}/tarefas/nova`);
    await pagina.waitForURL(/\/login$/);
    await pagina.locator('input[type=email]').waitFor();
    await print(pagina, 'Fig_6_5', '/tarefas/nova sem sessão redireciona para /login');
    await entrar(pagina, 'usuario@portal.local', usuario);
    await pagina.waitForURL(/\/tarefas\/nova$/);
    await pagina.getByRole('heading', { name: 'Nova tarefa' }).waitFor();
    await print(pagina, 'Fig_6_5b', 'após entrar, volta para /tarefas/nova');

    // 6.6 – recarregar autenticado: sessão restaurada; Excluir só para administrador
    await pagina.goto(`${BASE}/tarefas/${SEED1}`);
    await pagina.reload();
    await pagina.locator('article h1').waitFor();
    await print(pagina, 'Fig_6_6', 'usuário comum após recarregar: sessão mantida, sem Excluir');
    await pagina.getByRole('button', { name: 'Sair' }).click();
    await pagina.waitForURL(/\/login$/);
    await entrar(pagina, 'admin@portal.local', admin);
    await pagina.waitForURL(/\/tarefas/);
    await pagina.goto(`${BASE}/tarefas/${SEED1}`);
    await pagina.reload();
    await pagina.getByRole('button', { name: 'Excluir' }).waitFor();
    await print(pagina, 'Fig_6_6b', 'administrador após recarregar: botão Excluir visível');

    // 6.7 – armazenamento do navegador
    const armazenamento = await pagina.evaluate(() => ({
      local: Object.keys(localStorage), sessao: Object.keys(sessionStorage), cookieJs: document.cookie,
    }));
    const cookies = (await contexto.cookies()).map((c) => ({
      nome: c.name, dominio: c.domain, httpOnly: c.httpOnly, secure: c.secure, sameSite: c.sameSite,
    }));
    writeFileSync(path.join(evid, '_tmp', 'armazenamento-6_7.json'),
      JSON.stringify({ url: pagina.url(), ...armazenamento, cookies }, null, 2), 'utf8');
  } finally { await navegador.close(); }
}

const cenario = process.argv[2];
const mapa = { 'r5': cenarioR5, 'r5-erro': cenarioR5Erro, 'r6': cenarioR6 };
if (!mapa[cenario]) { console.error('Cenário desconhecido: ' + cenario); process.exit(2); }
mapa[cenario]().catch((e) => { console.error('ERRO no navegador: ' + e.message); process.exit(1); });
