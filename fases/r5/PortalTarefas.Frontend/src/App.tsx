import { Navigate, Route, Routes } from 'react-router-dom';
import DetalhesTarefa from './pages/DetalhesTarefa';
import FormTarefa from './pages/FormTarefa';
import ListaTarefas from './pages/ListaTarefas';

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Navigate to="/tarefas" replace />} />
      <Route path="/tarefas" element={<ListaTarefas />} />
      <Route path="/tarefas/nova" element={<FormTarefa />} />
      <Route path="/tarefas/:id" element={<DetalhesTarefa />} />
      <Route path="*" element={<p role="alert">Página não encontrada.</p>} />
    </Routes>
  );
}
