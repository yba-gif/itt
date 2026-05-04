import { useMutation } from "@tanstack/react-query";
import { useState } from "react";

import { api } from "../api/client";

const KANTONS = [
  "AG","AI","AR","BE","BL","BS","FR","GE","GL","GR","JU","LU","NE",
  "NW","OW","SG","SH","SO","SZ","TG","TI","UR","VD","VS","ZG","ZH",
];

export default function PushComposer() {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [category, setCategory] = useState<"events" | "editorial" | "saved_search" | "my_listing">("editorial");
  const [kanton, setKanton] = useState("");
  const [confirmed, setConfirmed] = useState(false);
  const [result, setResult] = useState<{ sent: number; targeted: number } | null>(null);

  const send = useMutation({
    mutationFn: () => api.pushBroadcast(title, body, category, kanton || null),
    onSuccess: (r) => setResult(r),
  });

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
      <section className="bg-white border rounded p-4">
        <h1 className="text-xl font-semibold mb-4">Bildirim Gönder</h1>

        <label className="block text-sm font-medium mb-1">Başlık</label>
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          maxLength={120}
          className="w-full border rounded px-3 py-2 mb-3"
        />

        <label className="block text-sm font-medium mb-1">Metin</label>
        <textarea
          value={body}
          onChange={(e) => setBody(e.target.value)}
          maxLength={400}
          className="w-full border rounded px-3 py-2 mb-3 h-32"
        />

        <label className="block text-sm font-medium mb-1">Kategori</label>
        <select
          value={category}
          onChange={(e) => setCategory(e.target.value as "events" | "editorial" | "saved_search" | "my_listing")}
          className="w-full border rounded px-3 py-2 mb-3"
        >
          <option value="editorial">Editör güncellemesi</option>
          <option value="events">Yeni etkinlik</option>
          <option value="saved_search">Kayıtlı arama eşleşmesi</option>
          <option value="my_listing">İlan durumu</option>
        </select>

        <label className="block text-sm font-medium mb-1">Kanton (opsiyonel — boş = tümü)</label>
        <select
          value={kanton}
          onChange={(e) => setKanton(e.target.value)}
          className="w-full border rounded px-3 py-2 mb-4"
        >
          <option value="">Tüm kantonlar</option>
          {KANTONS.map((k) => (<option key={k} value={k}>{k}</option>))}
        </select>

        <label className="text-sm flex items-center gap-2 mb-3">
          <input
            type="checkbox"
            checked={confirmed}
            onChange={(e) => setConfirmed(e.target.checked)}
          />
          Onay: Bu metni gerçekten göndereceğimi anlıyorum.
        </label>

        <button
          onClick={() => send.mutate()}
          disabled={!confirmed || !title || !body || send.isPending}
          className="bg-brand-500 hover:bg-brand-600 disabled:opacity-60 text-white px-4 py-2 rounded"
        >
          {send.isPending ? "Gönderiliyor…" : "Gönder"}
        </button>

        {result && (
          <div className="mt-4 text-sm text-slate-700">
            Hedef: {result.targeted} cihaz • Gönderilen: {result.sent}
          </div>
        )}
        {send.error && (
          <div className="mt-3 text-sm text-red-600">Hata: {String(send.error)}</div>
        )}
      </section>

      <section className="bg-white border rounded p-4">
        <div className="text-xs uppercase text-slate-400 mb-2">Önizleme</div>
        <div className="border border-slate-200 rounded-lg p-4 bg-slate-50">
          <div className="text-xs text-slate-400">ITT-Rehber</div>
          <div className="font-semibold">{title || "(başlık)"}</div>
          <div className="text-sm text-slate-600 mt-1">{body || "(metin)"}</div>
        </div>
        <div className="text-xs text-slate-400 mt-3">
          Kategori: {category}
          {kanton && ` • Kanton: ${kanton}`}
        </div>
      </section>
    </div>
  );
}
