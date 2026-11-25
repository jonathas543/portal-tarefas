import { useEffect, useRef, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { mensagemDeErro } from '../api/apiClient';
import { listarTarefas } from '../api/tarefasApi';
import type { ConsultaTarefas, Pagina, TarefaResumo } from '../api/tipos';

type Estado =
  | { fase: 'idle' }
  | { fase: 'carregando' }
  | { fase: 'vazio' }
  | { fase: 'sucesso'; dados: Pagina<TarefaResumo> }
  | { fase: 'erro'; mensagem: string };

function lerConsulta(p: URLSearchParams): ConsultaTarefas {
  return {
    pagina: Number(p.get('pagina')) || 1,
    tamanho: 10,
    ordenarPor: p.get('ordenarPor') ?? 'titulo',
    direcao: p.get('direcao') === 'desc' ? 'desc' : 'asc',
    situacao: p.get('situacao') ?? undefined,
    busca: p.get('busca') ?? undefined,
  };
}

export default function ListaTarefas() {
  const [params, setParams] = useSearchParams();
  const [estado, setEstado] = useState<Estado>({ fase: 'idle' });
  const titulo = useRef<HTMLHeadingElement>(null);
  const consulta = lerConsulta(params);
  const chave = params.toString();

  useEffect(() => { titulo.current?.focus(); }, []);

  useEffect(() => {
    const controle = new AbortController();
    setEstado({ fase: 'carregando' });
    listarTarefas(lerConsulta(new URLSearchParams(chave)), controle.signal)
      .then((d) => setEstado(d.itens.length > 0 ? { fase: 'sucesso', dados: d } : { fase: 'vazio' }))
      .catch((e) => {
        if (e instanceof DOMException && e.name === 'AbortError') return;   // resposta obsoleta
        setEstado({ fase: 'erro', mensagem: mensagemDeErro(e) });
      });
    return () => controle.abort();
  }, [chave]);

  function atualizar(mudancas: Record<string, string | undefined>) {
    setParams((anteriores) => {
      const novos = new URLSearchParams(anteriores);
      for (const [k, v] of Object.entries(mudancas)) { if (v) novos.set(k, v); else novos.delete(k); }
      return novos;
    });
  }

  return (
    <section>
      <h1 ref={titulo} tabIndex={-1}>Tarefas</h1>
      <Link to="/tarefas/nova">Nova tarefa</Link>

      <label>Situação{' '}
        <select value={consulta.situacao ?? ''} onChange={(e) => atualizar({ situacao: e.target.value, pagina: '1' })}>
          <option value="">Todas</option>
          <option value="Pendente">Pendente</option>
          <option value="EmAndamento">Em andamento</option>
          <option value="Concluida">Concluída</option>
        </select>
      </label>

      {estado.fase === 'carregando' && <p role="status" aria-live="polite">Carregando…</p>}
      {estado.fase === 'vazio' && <p role="status">Nenhuma tarefa encontrada.</p>}
      {estado.fase === 'erro' && <p role="alert">{estado.mensagem}</p>}
      {estado.fase === 'sucesso' && (
        <>
          <ul>
            {estado.dados.itens.map((t) => (
              <li key={t.id}><Link to={`/tarefas/${t.id}`}>{t.titulo}</Link> – {t.situacao}</li>
            ))}
          </ul>
          <nav aria-label="Paginação">
            <button disabled={consulta.pagina <= 1} onClick={() => atualizar({ pagina: String(consulta.pagina - 1) })}>Anterior</button>
            <span> Página {estado.dados.pagina} de {estado.dados.totalPaginas} </span>
            <button disabled={consulta.pagina >= estado.dados.totalPaginas} onClick={() => atualizar({ pagina: String(consulta.pagina + 1) })}>Próxima</button>
          </nav>
        </>
      )}
    </section>
  );
}
