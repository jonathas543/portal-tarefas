import type { ProblemDetails } from './tipos';

const API_BASE = import.meta.env.VITE_API_BASE ?? '/api';

export class ApiError extends Error {
  // campos explícitos (o tsconfig do Vite usa erasableSyntaxOnly, que não aceita "parameter properties")
  readonly tipo: 'rede' | 'http';
  readonly status?: number;
  readonly problem?: ProblemDetails;

  constructor(tipo: 'rede' | 'http', status?: number, problem?: ProblemDetails, mensagem?: string) {
    super(mensagem ?? problem?.detail ?? problem?.title ?? 'Erro inesperado.');
    this.name = 'ApiError';
    this.tipo = tipo;
    this.status = status;
    this.problem = problem;
  }
}

export async function fetchApi<T>(caminho: string, init: RequestInit = {}): Promise<T> {
  let resposta: Response;
  try {
    resposta = await fetch(`${API_BASE}${caminho}`, {
      ...init,
      credentials: 'same-origin',
      headers: {
        Accept: 'application/json',
        ...(init.body ? { 'Content-Type': 'application/json' } : {}),
        ...init.headers,
      },
    });
  } catch (e) {
    if (e instanceof DOMException && e.name === 'AbortError') throw e;      // cancelamento intencional
    throw new ApiError('rede', undefined, undefined, 'Não foi possível contactar o servidor.');
  }

  if (!resposta.ok) {
    let problem: ProblemDetails | undefined;
    try { problem = await resposta.json(); } catch { /* resposta sem corpo JSON */ }
    // 5xx sem Problem Details: veio do proxy do Vite (API fora do ar) -> tratado como erro de rede
    if (!problem && resposta.status >= 500)
      throw new ApiError('rede', resposta.status, undefined, 'Não foi possível contactar o servidor.');
    throw new ApiError('http', resposta.status, problem);
  }
  if (resposta.status === 204) return undefined as T;
  return (await resposta.json()) as T;
}

export function mensagemDeErro(e: unknown): string {
  return e instanceof ApiError ? e.message : 'Erro inesperado.';
}

/** Converte as chaves de erro de validação para camelCase (nomes dos campos do formulário). */
export function errosPorCampo(e: unknown): Record<string, string[]> {
  const saida: Record<string, string[]> = {};
  if (e instanceof ApiError && e.problem?.errors) {
    for (const [chave, msgs] of Object.entries(e.problem.errors)) {
      saida[chave.charAt(0).toLowerCase() + chave.slice(1)] = msgs;
    }
  }
  return saida;
}
