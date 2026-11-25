import { type ReactElement, useContext } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { AuthContext } from './AuthContext';

export default function ProtectedRoute({ children, role }: { children: ReactElement; role?: string }) {
  const { usuario, carregando, temRole } = useContext(AuthContext);
  const local = useLocation();
  if (carregando) return <p role="status" aria-live="polite">Verificando sessão…</p>;
  if (!usuario) return <Navigate to="/login" replace state={{ de: local }} />;   // guarda a URL pretendida
  if (role && !temRole(role)) return <p role="alert">Acesso negado.</p>;
  return children;
}
