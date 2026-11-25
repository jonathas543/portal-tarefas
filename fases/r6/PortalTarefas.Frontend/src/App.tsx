import { Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider } from './auth/AuthContext';
import ProtectedRoute from './auth/ProtectedRoute';
import DetalhesTarefa from './pages/DetalhesTarefa';
import FormTarefa from './pages/FormTarefa';
import ListaTarefas from './pages/ListaTarefas';
import Login from './pages/Login';

export default function App() {
  return (
    <AuthProvider>
      <Routes>
        <Route path="/" element={<Navigate to="/tarefas" replace />} />
        <Route path="/login" element={<Login />} />
        <Route path="/tarefas" element={<ProtectedRoute><ListaTarefas /></ProtectedRoute>} />
        <Route path="/tarefas/nova" element={<ProtectedRoute><FormTarefa /></ProtectedRoute>} />
        <Route path="/tarefas/:id" element={<ProtectedRoute><DetalhesTarefa /></ProtectedRoute>} />
        <Route path="*" element={<p role="alert">Página não encontrada.</p>} />
      </Routes>
    </AuthProvider>
  );
}
