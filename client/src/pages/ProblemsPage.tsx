import { useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { QuestionWorkspace } from '../components/QuestionWorkspace';
import { Sidebar } from '../components/Sidebar';
import { readLS, writeLS } from '../hooks';
import { useApp } from '../state';

export function ProblemsPage() {
  const { id } = useParams();
  const { questions, loading, error } = useApp();
  const navigate = useNavigate();

  // remember the last opened question; open it (or the first one) when none is selected
  useEffect(() => {
    if (id) {
      writeLS('csim:lastQuestion', id);
      return;
    }
    if (!questions.length) return;
    const last = readLS<string | null>('csim:lastQuestion', null);
    const target = questions.find((q) => q.id === last) || questions[0];
    navigate(`/problems/${target.id}`, { replace: true });
  }, [id, questions, navigate]);

  return (
    <div className="flex h-full">
      <div className="w-80 shrink-0">
        <Sidebar activeId={id} />
      </div>
      <div className="min-w-0 flex-1">
        {error && <div className="p-6 text-rose-300">{error}</div>}
        {!error && loading && <div className="p-6 text-slate-500">Loading questions…</div>}
        {!error && !loading && questions.length === 0 && (
          <div className="p-6 text-slate-400">
            No questions found. Run <code className="text-slate-200">npm run build:questions</code>.
          </div>
        )}
        {id && <QuestionWorkspace key={id} id={id} />}
      </div>
    </div>
  );
}
