import { useState } from "react";
import { useQuery } from "@tanstack/react-query";

import { api } from "../api/client";

const PAGE_SIZE = 50;

export default function AIQuestions() {
  const [page, setPage] = useState(1);

  const { data, isLoading, error } = useQuery({
    queryKey: ["ai-questions", page],
    queryFn: () => api.aiQuestions({ page, pageSize: PAGE_SIZE }),
  });

  const totalPages = data ? Math.max(1, Math.ceil(data.total / PAGE_SIZE)) : 1;

  return (
    <div>
      <h1 className="text-xl font-semibold mb-1">
        İTT AI Sorular{data && ` (${data.total})`}
      </h1>
      <p className="text-sm text-slate-500 mb-4">
        Kullanıcıların İTT AI'ya sorduğu sorular. Yanıt karakteri sıfır olan kayıtlar
        OpenAI tarafından döndürülen hatadır.
      </p>

      {isLoading && <div className="text-slate-500">Yükleniyor…</div>}
      {error && <div className="text-red-600">Hata: {String(error)}</div>}

      {data && data.items.length === 0 && (
        <div className="bg-white border border-slate-200 rounded p-6 text-slate-500 text-center">
          Henüz soru kaydı yok.
        </div>
      )}

      {data && data.items.length > 0 && (
        <div className="bg-white border border-slate-200 rounded overflow-x-auto">
          <table className="w-full text-sm min-w-[600px]">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="text-left px-4 py-2.5 font-medium w-44">Tarih</th>
                <th className="text-left px-4 py-2.5 font-medium">Soru</th>
                <th className="text-right px-4 py-2.5 font-medium w-28">Yanıt</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {data.items.map((q) => (
                <tr key={q.id} className="hover:bg-slate-50">
                  <td className="px-4 py-2.5 text-slate-500 text-xs whitespace-nowrap align-top">
                    {new Date(q.created_at).toLocaleString("tr-CH", {
                      day: "2-digit",
                      month: "2-digit",
                      year: "numeric",
                      hour: "2-digit",
                      minute: "2-digit",
                    })}
                  </td>
                  <td className="px-4 py-2.5 text-slate-800">
                    {q.question}
                  </td>
                  <td className="px-4 py-2.5 text-right text-xs align-top whitespace-nowrap">
                    {q.response_chars === 0 ? (
                      <span className="text-red-600 font-medium">Hata</span>
                    ) : (
                      <span className="text-slate-500">{q.response_chars} karakter</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {data && totalPages > 1 && (
        <div className="mt-4 flex items-center gap-2 text-sm">
          <button
            disabled={page <= 1}
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            className="px-3 py-1.5 border border-slate-300 rounded disabled:opacity-40"
          >
            ← Önceki
          </button>
          <div className="text-slate-500">
            Sayfa {page} / {totalPages}
          </div>
          <button
            disabled={page >= totalPages}
            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
            className="px-3 py-1.5 border border-slate-300 rounded disabled:opacity-40"
          >
            Sonraki →
          </button>
        </div>
      )}
    </div>
  );
}
