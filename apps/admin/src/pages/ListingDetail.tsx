import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { useNavigate, useParams } from "react-router-dom";

import { api, REJECTION_REASONS, type Listing } from "../api/client";

export default function ListingDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [reasonCode, setReasonCode] = useState<string>(REJECTION_REASONS[0].code);
  const [notes, setNotes] = useState<string>("");
  const [showReject, setShowReject] = useState(false);

  // Try the queue caches first (instant), fall back to a direct fetch
  // so direct-URL navigation and page-refresh both work.
  const cachedListing = (() => {
    for (const s of ["pending", "active", "rejected", "suspended"] as Listing["status"][]) {
      const hit = qc.getQueryData<Listing[]>(["queue", s])?.find((l) => l.id === id);
      if (hit) return hit;
    }
    return undefined;
  })();

  const { data: fetchedListing, isLoading, error } = useQuery({
    queryKey: ["listing", id],
    queryFn: () => api.getListing(id!),
    enabled: !cachedListing && !!id,
  });

  const listing = cachedListing ?? fetchedListing ?? null;

  const approveMut = useMutation({
    mutationFn: () => api.approve(id!),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["queue"] });
      navigate("/queue?status=pending");
    },
  });

  const rejectMut = useMutation({
    mutationFn: () => api.reject(id!, reasonCode, notes || undefined),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["queue"] });
      navigate("/queue?status=pending");
    },
  });

  if (isLoading) return <div className="text-slate-500">Yükleniyor…</div>;
  if (error) return <div className="text-red-600">Hata: {String(error)}</div>;
  if (!listing) return <div className="text-slate-500">Kayıt bulunamadı.</div>;

  return (
    <div>
      <button
        onClick={() => navigate(-1)}
        className="text-sm text-slate-500 hover:text-slate-700 mb-4"
      >
        ← Geri
      </button>

      <div className="bg-white border border-slate-200 rounded p-6 mb-6">
        <h1 className="text-xl font-semibold">{listing.name}</h1>
        <div className="text-sm text-slate-500 mt-1">
          {listing.directories.join(", ")} • {listing.kantons.join(", ")}
          {listing.category ? ` • ${listing.category}` : ""}
        </div>

        <dl className="mt-4 grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-3 text-sm">
          <Field label="İletişim kişisi" value={listing.contact_person} />
          <Field label="Adres" value={listing.address} />
          <Field
            label="Telefon"
            value={listing.phone ? `${listing.phone} ${listing.phone_public ? "(görünür)" : "(gizli)"}` : null}
          />
          <Field
            label="E-posta"
            value={listing.email ? `${listing.email} ${listing.email_public ? "(görünür)" : "(gizli)"}` : null}
          />
          <Field label="Web sitesi" value={listing.website} />
          <Field label="Görsel" value={listing.image_url ? "Yüklendi" : "—"} />
        </dl>

        {listing.description && (
          <div className="mt-4">
            <div className="text-sm font-medium mb-1">Açıklama</div>
            <div className="text-sm text-slate-700 whitespace-pre-wrap">{listing.description}</div>
          </div>
        )}

        <div className="mt-4 text-xs text-slate-400">
          Durum: {listing.status} • Oluşturulma: {new Date(listing.created_at).toLocaleString("tr-TR")}
        </div>
      </div>

      {listing.status === "pending" && (
        <div className="flex flex-wrap gap-3">
          <button
            disabled={approveMut.isPending}
            onClick={() => approveMut.mutate()}
            className="bg-emerald-600 hover:bg-emerald-700 disabled:opacity-60 text-white px-4 py-2 rounded font-medium"
          >
            {approveMut.isPending ? "Onaylanıyor…" : "Onayla"}
          </button>
          <button
            onClick={() => setShowReject((v) => !v)}
            className="bg-white border border-red-300 text-red-700 hover:bg-red-50 px-4 py-2 rounded font-medium"
          >
            Reddet
          </button>
        </div>
      )}

      {showReject && listing.status === "pending" && (
        <div className="mt-4 bg-white border border-slate-200 rounded p-4">
          <div className="text-sm font-medium mb-2">Red sebebi</div>
          <select
            value={reasonCode}
            onChange={(e) => setReasonCode(e.target.value)}
            className="w-full border rounded px-3 py-2 mb-3"
          >
            {REJECTION_REASONS.map((r) => (
              <option key={r.code} value={r.code}>{r.label}</option>
            ))}
          </select>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="(opsiyonel) Detay"
            className="w-full border rounded px-3 py-2 mb-3 h-24"
          />
          <button
            disabled={rejectMut.isPending}
            onClick={() => rejectMut.mutate()}
            className="bg-red-600 hover:bg-red-700 disabled:opacity-60 text-white px-4 py-2 rounded font-medium"
          >
            {rejectMut.isPending ? "Reddediliyor…" : "Reddi onayla"}
          </button>
        </div>
      )}

      {(approveMut.error || rejectMut.error) && (
        <div className="mt-3 text-sm text-red-600">
          Hata: {String(approveMut.error || rejectMut.error)}
        </div>
      )}
    </div>
  );
}

function Field({ label, value }: { label: string; value: string | null | undefined }) {
  return (
    <div>
      <dt className="text-xs uppercase tracking-wide text-slate-400">{label}</dt>
      <dd className="text-slate-700">{value || "—"}</dd>
    </div>
  );
}
