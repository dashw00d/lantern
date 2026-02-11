import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AppLayout } from './components/layout/AppLayout';
import { Dashboard } from './pages/Dashboard';
import { Projects } from './pages/Projects';
import { ProjectDetail } from './pages/ProjectDetail';
import { Services } from './pages/Services';
import { Settings } from './pages/Settings';
import { useHealthChannel } from './hooks/useHealth';
import { useProjectChannel } from './hooks/useProjects';
import { useElectronBridge } from './hooks/useElectronBridge';
import { ToastContainer } from './components/common/Toast';

export function App() {
  // Connect to Phoenix channels on app start
  useHealthChannel();
  useProjectChannel();
  useElectronBridge();

  return (
    <BrowserRouter>
      <Routes>
        <Route element={<AppLayout />}>
          <Route path="/" element={<Dashboard />} />
          <Route path="/projects" element={<Projects />} />
          <Route path="/projects/:name" element={<ProjectDetail />} />
          <Route path="/services" element={<Services />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
      <ToastContainer />
    </BrowserRouter>
  );
}
