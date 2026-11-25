import { type FormEvent, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { errosPorCampo, mensagemDeErro } from '../api/apiClient';
import { criarTarefa } from '../api/tarefasApi';
import type { Prioridade } from '../api/tipos';

export default function FormTarefa() {
  const navegar = useNavigate();
  const [titulo, setTitulo] = useState('');
  const [descricao, setDescricao] = useState('');
  const [prioridade, setPrioridade] = useState<Prioridade>('Normal');
  const [prazo, setPrazo] = useState('');
  const [erros, setErros] = useState<Record<string, string[]>>({});
  const [erroGeral, setErroGeral] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);

  async function enviar(e: FormEvent) {
    e.preventDefault();
    setEnviando(true); setErros({}); setErroGeral(null);
    try {
      // campo vazio vai como ausente: a API responde "O prazo é obrigatório." no próprio campo
      const nova = await criarTarefa({ titulo, descricao: descricao || undefined, prioridade, prazo: prazo || undefined });
      navegar(`/tarefas/${nova.id}`);            // atualiza a interface sem recarregar a página
    } catch (err) {
      const porCampo = errosPorCampo(err);
      if (Object.keys(porCampo).length > 0) setErros(porCampo); else setErroGeral(mensagemDeErro(err));
    } finally {
      setEnviando(false);
    }
  }

  return (
    <form onSubmit={enviar} noValidate>
      <h1>Nova tarefa</h1>
      {erroGeral && <p role="alert">{erroGeral}</p>}
      <label>Título <input value={titulo} onChange={(e) => setTitulo(e.target.value)} aria-invalid={!!erros.titulo} /></label>
      {erros.titulo?.map((m) => <span key={m} role="alert"> {m}</span>)}
      <label>Descrição <textarea value={descricao} onChange={(e) => setDescricao(e.target.value)} /></label>
      <label>Prioridade
        <select value={prioridade} onChange={(e) => setPrioridade(e.target.value as Prioridade)}>
          <option>Baixa</option><option>Normal</option><option>Urgente</option>
        </select>
      </label>
      <label>Prazo <input type="date" value={prazo} onChange={(e) => setPrazo(e.target.value)} aria-invalid={!!erros.prazo} /></label>
      {erros.prazo?.map((m) => <span key={m} role="alert"> {m}</span>)}
      <button type="submit" disabled={enviando}>{enviando ? 'Salvando…' : 'Salvar'}</button>
    </form>
  );
}
