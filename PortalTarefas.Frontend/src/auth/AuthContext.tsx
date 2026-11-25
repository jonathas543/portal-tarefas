import { createContext, type ReactNode, useCallback, useEffect, useMemo, useState } from 'react';
import { fetchApi } from '../api/apiClient';

export interface Usuario { email: string; roles: string[]; permissoes: string[]; }
interface AuthCtx {
  usuario: Usuario | null; carregando: boolean;
  entrar(email: string, senha: string): Promise<void>; sair(): Promise<void>; temRole(role: string): boolean;
}

export const AuthContext = createContext<AuthCtx>(null!);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [usuario, setUsuario] = useState<Usuario | null>(null);
  const [carregando, setCarregando] = useState(true);

  const carregarSessao = useCallback(async () => {
    try { setUsuario(await fetchApi<Usuario>('/conta/me')); }       // restaura a sessão (cookie HttpOnly)
    catch { setUsuario(null); }
    finally { setCarregando(false); }
  }, []);

  useEffect(() => { carregarSessao(); }, [carregarSessao]);

  const valor = useMemo<AuthCtx>(() => ({
    usuario, carregando,
    entrar: async (email, senha) => {
      await fetchApi<void>('/conta/login', { method: 'POST', body: JSON.stringify({ email, senha }) });
      await carregarSessao();
    },
    sair: async () => { await fetchApi<void>('/conta/logout', { method: 'POST' }); setUsuario(null); },
    temRole: (role) => usuario?.roles.includes(role) ?? false,
  }), [usuario, carregando, carregarSessao]);

  return <AuthContext.Provider value={valor}>{children}</AuthContext.Provider>;
}
