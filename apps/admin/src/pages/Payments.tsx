import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";

import { api, type Invoice } from "../api/client";

export default function Payments() {
  const qc = useQueryClient();
  const [showPaid, setShowPaid] = useState(false);

  const { data, isLoading, error } = useQuery({
    queryKey: ["invoices", showPaid ? "all" : "unpaid"],
    queryFn: () => api.invoices(!showPaid),
  });

  const markPaid = useMutation({
    mutationFn: ({ id, method }: { id: string; method: "twint" | "bank" }) =>
      api.markPaid(id, method),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["invoices"] }),
  });

  if (isLoading) return <div className="text-slate-500">Yükleniyor…</div>;
  if (error) return <div className="text-red-600">Hata: {String(error)}</div>;

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-xl font-semibold">
          Ödemeler — {showPaid ? "Tümü" : "Bekleyen"} ({data?.length ?? 0})
        </h1>
        <label className="text-sm flex items-center gap-2">
          <input
            type="checkbox"
            checked={showPaid}
            onChange={(e) => setShowPaid(e.target.checked)}
          />
          Ödenenler dahil
        </label>
      </div>

      <div className="bg-white border border-slate-200 rounded divide-y">
        {data && data.length === 0 && (
          <div className="px-4 py-6 text-slate-500 text-center">
            {showPaid ? "Hiç fatura yok." : "Bekleyen ödeme yok."}
          </div>
        )}
        {data?.map((inv) => (
          <div key={inv.id} className="px-4 py-3">
            <div className="flex items-start justify-between gap-4">
              <div>
                <div className="font-medium">{inv.invoice_number}</div>
                <div className="text-sm text-slate-500">
                  {(inv.amount_chf / 100).toFixed(2)} CHF • {inv.package}
                  {inv.due_at && ` • Vade: ${new Date(inv.due_at).toLocaleDateString("tr-TR")}`}
                </div>
                {inv.paid_at && (
                  <div className="text-xs text-emerald-700 mt-1">
                    {new Date(inv.paid_at).toLocaleDateString("tr-TR")} • {inv.payment_method}
                  </div>
                )}
              </div>
              <div className="flex flex-col gap-2 shrink-0">
                {inv.pdf_url && (
                  <a
                    href={inv.pdf_url}
                    target="_blank"
                    rel="noreferrer"
                    className="text-sm text-brand-500 hover:underline"
                  >
                    PDF
                  </a>
                )}
                {!inv.paid_at && (
                  <div className="flex gap-2">
                    <button
                      onClick={() => markPaid.mutate({ id: inv.id, method: "twint" })}
                      disabled={markPaid.isPending}
                      className="bg-emerald-600 hover:bg-emerald-700 disabled:opacity-60 text-white text-sm px-3 py-1 rounded"
                    >
                      TWINT alındı
                    </button>
                    <button
                      onClick={() => markPaid.mutate({ id: inv.id, method: "bank" })}
                      disabled={markPaid.isPending}
                      className="bg-emerald-600 hover:bg-emerald-700 disabled:opacity-60 text-white text-sm px-3 py-1 rounded"
                    >
                      Havale alındı
                    </button>
                  </div>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
