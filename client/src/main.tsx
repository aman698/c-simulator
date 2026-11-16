import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import './index.css';
import { Layout } from './components/Layout';
import { DashboardPage } from './pages/DashboardPage';
import { InterviewPage } from './pages/InterviewPage';
import { PlaygroundPage } from './pages/PlaygroundPage';
import { ProblemsPage } from './pages/ProblemsPage';
import { AppProvider } from './state';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <AppProvider>
      <BrowserRouter>
        <Routes>
          <Route element={<Layout />}>
            <Route index element={<Navigate to="/problems" replace />} />
            <Route path="problems" element={<ProblemsPage />} />
            <Route path="problems/:id" element={<ProblemsPage />} />
            <Route path="dashboard" element={<DashboardPage />} />
            <Route path="interview" element={<InterviewPage />} />
            <Route path="playground" element={<PlaygroundPage />} />
            <Route path="*" element={<Navigate to="/problems" replace />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AppProvider>
  </StrictMode>,
);
