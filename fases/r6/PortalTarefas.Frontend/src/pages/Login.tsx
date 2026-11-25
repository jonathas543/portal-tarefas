import { type FormEvent, useContext, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { AuthContext } from '../auth/AuthContext';

export default function Login() {
  const { entrar } = useContext(AuthContext);
  const navegar = useNavigate();
  const { state } = useLocation() as { state?: { de?: { pathname: string; search: string } } };
  const [email, setEmail] = useState('');
  const [senha, setSenha] = useState('');
  const [erro, setErro] = useState<string | null>(null);

  async function enviar(e: FormEvent) {
    e.preventDefault();
    try {
      await entrar(email, senha);
      navegar(state?.de ? state.de.pathname + state.de.search : '/tarefas', { replace: true });
    } catch { setErro('E-mail ou senha inválidos.'); }
  }

  return (
    <form onSubmit={enviar}>
      <h1>Entrar</h1>
      {erro && <p role="alert">{erro}</p>}
      <label>E-mail <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="username" /></label>
      <label>Senha <input type="password" value={senha} onChange={(e) => setSenha(e.target.value)} autoComplete="current-password" /></label>
      <button type="submit">Entrar</button>
    </form>
  );
}
