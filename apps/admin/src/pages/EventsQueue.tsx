import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useSearchParams } from "react-router-dom";

import { api, type Event } from "../api/client";

const STATUS_LABELS: Record<Event["status"], string> = {
  pending: "Beklemede",
  active: "Yayında",
  rejected: "Reddedildi",
};

export default function EventsQueue() {
  const [params] = useSearchParams();
  const status = (params.get("status") as Event["status"]) || "pending";
  const qc = useQueryClient();

  const { data, isLoading, error } = useQuery({
    queryKey: ["events", status],
    queryFn: () => api.eventQueue(status),
  });

  const approve = useMutation({
    mutationFn: (id: string) => api.approveEvent(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["events"] }),
  });
  const reject = useMutation({
    mutationFn: (id: string) => api.rejectEvent(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["events"] }),
  });

  if (isLoading) return <div className="text-slate-500">Yükleniyor…</div>;
  if (error) return <div className="text-red-600">Hata: {String(error)}</div>;

  return (
    <div>
      <h1 className="text-xl font-semibold mb-4">Etkinlikler — {STATUS_LABELS[status]} ({data?.length ?? 0})</h1>

      <div className="bg-white border border-slate-200 rounded divide-y">
        {data && data.length === 0 && (
          <div className="px-4 py-6 text-slate-500 text-center">Bu durumda etkinlik yok.</div>
        )}
        {data?.map((event) => (
          <div key={event.id} className="px-4 py-3">
            <div className="flex items-start justify-between gap-4">
              <div>
                <div className="font-medium">{event.title}</div>
                <div className="text-sm text-slate-500">
                  {new Date(event.starts_at).toLocaleString("tr-TR")} • {event.kanton}
                  {event.venue ? ` • ${event.venue}` : ""}
                </div>
                {event.description && (
                  <div className="text-sm text-slate-600 mt-2 whitespace-pre-wrap">{event.description}</div>
                )}
              </div>
              {status === "pending" && (
                <div className="flex flex-col gap-2 shrink-0">
                  <button
                    onClick={() => approve.mutate(event.id)}
                    disabled={approve.isPending}
                    className="bg-emerald-600 hover:bg-emerald-700 disabled:opacity-60 text-white text-sm px-3 py-1 rounded"
                  >Onayla</button>
                  <button
                    onClick={() => reject.mutate(event.id)}
                    disabled={reject.isPending}
                    className="bg-white border border-red-300 text-red-700 hover:bg-red-50 text-sm px-3 py-1 rounded"
                  >Reddet</button>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
