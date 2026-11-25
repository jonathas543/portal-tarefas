import { fetchApi } from './apiClient';
import type { ConsultaTarefas, Pagina, TarefaCriar, TarefaDetalhes, TarefaResumo } from './tipos';

export function listarTarefas(c: ConsultaTarefas, signal?: AbortSignal) {
  const q = new URLSearchParams({
    pagina: String(c.pagina), tamanho: String(c.tamanho), ordenarPor: c.ordenarPor, direcao: c.direcao,
  });
  if (c.situacao) q.set('situacao', c.situacao);
  if (c.busca) q.set('busca', c.busca);
  return fetchApi<Pagina<TarefaResumo>>(`/tarefas?${q}`, { signal });
}

export const obterTarefa = (id: string, signal?: AbortSignal) =>
  fetchApi<TarefaDetalhes>(`/tarefas/${encodeURIComponent(id)}`, { signal });

export const criarTarefa = (dto: TarefaCriar) =>
  fetchApi<TarefaDetalhes>('/tarefas', { method: 'POST', body: JSON.stringify(dto) });
