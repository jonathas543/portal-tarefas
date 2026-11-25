export type Prioridade = 'Baixa' | 'Normal' | 'Urgente';
export type Situacao = 'Pendente' | 'EmAndamento' | 'Concluida';

export interface TarefaResumo {
  id: string; titulo: string; prioridade: Prioridade; prazo: string; situacao: Situacao;
}
export interface TarefaDetalhes extends TarefaResumo { descricao: string | null; rowVersion: string; }
export interface Pagina<T> { itens: T[]; pagina: number; tamanho: number; total: number; totalPaginas: number; }
export interface TarefaCriar { titulo: string; descricao?: string; prioridade: Prioridade; prazo?: string; }

export interface ConsultaTarefas {
  pagina: number; tamanho: number; ordenarPor: string; direcao: 'asc' | 'desc';
  situacao?: string; busca?: string;
}

export interface ProblemDetails {
  type?: string; title?: string; status?: number; detail?: string;
  errors?: Record<string, string[]>;
}
