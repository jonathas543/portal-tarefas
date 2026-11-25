import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { ApiError, mensagemDeErro } from '../api/apiClient';
import { obterTarefa } from '../api/tarefasApi';
import type { TarefaDetalhes } from '../api/tipos';

export default function DetalhesTarefa() {
  const { id = '' } = useParams();
  const [tarefa, setTarefa] = useState<TarefaDetalhes | null>(null);
  const [erro, setErro] = useState<string | null>(null);
  const [carregando, setCarregando] = useState(true);

  useEffect(() => {
    const controle = new AbortController();
    setCarregando(true); setErro(null); setTarefa(null);
    obterTarefa(id, controle.signal)
      .then(setTarefa)
      .catch((e) => {
        if (e instanceof DOMException && e.name === 'AbortError') return;
        setErro(e instanceof ApiError && e.status === 404 ? 'Tarefa não encontrada.' : mensagemDeErro(e));
      })
      .finally(() => { if (!controle.signal.aborted) setCarregando(false); });
    return () => controle.abort();
  }, [id]);

  if (carregando) return <p role="status" aria-live="polite">Carregando…</p>;
  if (erro) return <p role="alert">{erro} <Link to="/tarefas">Voltar</Link></p>;
  if (!tarefa) return null;
  return (
    <article>
      <h1>{tarefa.titulo}</h1>
      <p>{tarefa.prioridade} · prazo {new Date(tarefa.prazo).toLocaleDateString('pt-BR')} · {tarefa.situacao}</p>
      <p>{tarefa.descricao ?? 'Sem descrição.'}</p>
      <Link to="/tarefas">Voltar</Link>
    </article>
  );
}
