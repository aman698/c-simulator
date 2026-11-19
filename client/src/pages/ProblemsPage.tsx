import { useEffect, useRef } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { QuestionWorkspace } from '../components/QuestionWorkspace';
import { Sidebar } from '../components/Sidebar';
import { readLS, writeLS } from '../hooks';
import { useApp } from '../state';

export function ProblemsPage() {
  const { id } = useParams();
  const { allQuestions, questions, track, setTrack, loading, error } = useApp();
  const navigate = useNavigate();
  const lastTrack = useRef(track);

  useEffect(() => {
    if (!allQuestions.length) return;
    const current = id ? allQuestions.find((q) => q.id === id) : undefined;
    const trackChanged = lastTrack.current !== track;
    lastTrack.current = track;

    // Opening a link to a question of the other track switches the track ...
    if (current && current.track !== track && !trackChanged) {
      setTrack(current.track);
      return;
    }
    if (current && current.track === track) {
      writeLS(`csim:lastQuestion:${track}`, current.id);
      return;
    }
    // ... while flipping the track switch (or opening /problems) shows that track's last question.
    if (!questions.length) return;
    const last = readLS<string | null>(`csim:lastQuestion:${track}`, null);
    const target = questions.find((q) => q.id === last) || questions[0];
    navigate(`/problems/${target.id}`, { replace: true });
  }, [id, allQuestions, questions, track, setTrack, navigate]);

  const showId = id && questions.some((q) => q.id === id) ? id : undefined;

  return (
    <div className="flex h-full">
      <div className="w-80 shrink-0">
        <Sidebar activeId={showId} />
      </div>
      <div className="min-w-0 flex-1">
        {error && <div className="p-6 text-rose-300">{error}</div>}
        {!error && loading && <div className="p-6 text-slate-500">Loading questions…</div>}
        {!error && !loading && questions.length === 0 && (
          <div className="p-6 text-slate-400">
            No questions in this track yet. Run <code className="text-slate-200">npm run build:questions</code>.
          </div>
        )}
        {showId && <QuestionWorkspace key={showId} id={showId} />}
      </div>
    </div>
  );
}
