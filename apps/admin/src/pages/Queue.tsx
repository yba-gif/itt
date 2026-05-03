import { useQuery } from "@tanstack/react-query";
import { Link, useSearchParams } from "react-router-dom";

import { api, type Listing } from "../api/client";

const STATUS_LABELS: Record<Listing["status"], string> = {
  pending: "Beklemede",
  active: "Yayında",
  rejected: "Reddedildi",
  suspended: "Askıda",
  expired: "Süresi doldu",
  archived: "Arşivlendi",
};

export default function Queue() {
  const [params] = useSearchParams();
  const status = (params.get("status") as Listing["status"]) || "pending";

  const { data, isLoading, error } = useQuery({
    queryKey: ["queue", status],
    queryFn: () => api.queue(status),
  });

  if (isLoading) return <div className="text-slate-500">Yükleniyor…</div>;
  if (error) return <div className="text-red-600">Hata: {String(error)}</div>;

  return (
    <div>
      <h1 className="text-xl font-semibold mb-4">{STATUS_LABELS[status]} ({data?.length ?? 0})</h1>

      {data && data.length === 0 && (
        <div className="bg-white border border-slate-200 rounded p-6 text-slate-500 text-center">
          Bu durumda kayıt yok.
        </div>
      )}

      <div className="bg-white border border-slate-200 rounded divide-y">
        {data?.map((listing) => (
          <Link
            key={listing.id}
            to={`/listings/${listing.id}`}
            className="block px-4 py-3 hover:bg-slate-50"
          >
            <div className="flex items-baseline justify-between gap-4">
              <div>
                <div className="font-medium">{listing.name}</div>
                <div className="text-sm text-slate-500">
                  {listing.directories.join(", ")} • {listing.kantons.join(", ")}
                  {listing.category ? ` • ${listing.category}` : ""}
                </div>
              </div>
              <div className="text-xs text-slate-400 whitespace-nowrap">
                {new Date(listing.created_at).toLocaleString("tr-TR")}
              </div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}
