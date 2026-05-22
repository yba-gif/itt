import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { api, type SocialRow, type SocialInput } from "../api/client";

const blankInput: SocialInput = {
  label: "",
  system_icon: "link",
  url: "https://",
  tint_hex: "#B82030",
  sort_order: 100,
};

export default function Socials() {
  const queryClient = useQueryClient();
  const { data, isLoading, error } = useQuery({
    queryKey: ["socials"],
    queryFn: api.socials,
  });

  const [editing, setEditing] = useState<SocialRow | null>(null);
  const [creating, setCreating] = useState(false);

  function invalidate() {
    queryClient.invalidateQueries({ queryKey: ["socials"] });
  }

  const removeM = useMutation({
    mutationFn: api.deleteSocial,
    onSuccess: invalidate,
  });

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-xl font-semibold">
          Sosyal Medya{data && ` (${data.length})`}
        </h1>
        <button
          onClick={() => setCreating(true)}
          className="px-3 py-1.5 bg-brand-600 text-white rounded text-sm hover:bg-brand-700"
        >
          + Yeni
        </button>
      </div>

      <p className="text-sm text-slate-500 mb-4">
        İTT Rehber → Bilgi → Bizi Takip Edin satırı. Sıralama düşükten yükseğe.
        Renk kodu (#RRGGBB) iOS'da chip ikonunun arka plan tonunu belirler.
      </p>

      {isLoading && <div className="text-slate-500">Yükleniyor…</div>}
      {error && <div className="text-red-600">Hata: {String(error)}</div>}

      {data && data.length === 0 && !creating && (
        <div className="bg-white border border-slate-200 rounded p-6 text-slate-500 text-center">
          Henüz sosyal medya kaydı yok.
        </div>
      )}

      <div className="bg-white border border-slate-200 rounded overflow-hidden">
        {data?.map((s, i) => (
          <div
            key={s.id}
            className={`flex items-center gap-3 p-3 ${i > 0 ? "border-t border-slate-100" : ""}`}
          >
            <div
              className="w-10 h-10 rounded-lg flex items-center justify-center text-white text-xs font-semibold"
              style={{ backgroundColor: s.tint_hex }}
            >
              {s.label.charAt(0).toUpperCase()}
            </div>
            <div className="flex-1 min-w-0">
              <div className="font-medium text-slate-800">
                {s.label} <span className="text-slate-400 font-normal text-xs">#{s.sort_order}</span>
              </div>
              <div className="text-xs text-slate-500 truncate">{s.url}</div>
              <div className="text-xs text-slate-400">icon: {s.system_icon} · tint: {s.tint_hex}</div>
            </div>
            <div className="flex gap-2 text-sm">
              <button
                onClick={() => setEditing(s)}
                className="px-2.5 py-1 border border-slate-300 rounded hover:bg-slate-50"
              >
                Düzenle
              </button>
              <button
                onClick={() => {
                  if (window.confirm(`"${s.label}" silinsin mi?`)) removeM.mutate(s.id);
                }}
                className="px-2.5 py-1 border border-red-300 text-red-700 rounded hover:bg-red-50"
              >
                Sil
              </button>
            </div>
          </div>
        ))}
      </div>

      {creating && (
        <SocialForm
          initial={blankInput}
          title="Yeni sosyal medya"
          onCancel={() => setCreating(false)}
          onSubmit={async (payload) => {
            await api.createSocial(payload);
            setCreating(false);
            invalidate();
          }}
        />
      )}
      {editing && (
        <SocialForm
          initial={socialToInput(editing)}
          title={`${editing.label} düzenle`}
          onCancel={() => setEditing(null)}
          onSubmit={async (payload) => {
            await api.updateSocial(editing.id, payload);
            setEditing(null);
            invalidate();
          }}
        />
      )}
    </div>
  );
}

function socialToInput(s: SocialRow): SocialInput {
  const { id: _id, updated_at: _u, ...rest } = s;
  return rest;
}

function SocialForm({
  initial,
  title,
  onCancel,
  onSubmit,
}: {
  initial: SocialInput;
  title: string;
  onCancel: () => void;
  onSubmit: (payload: SocialInput) => Promise<void>;
}) {
  const [form, setForm] = useState<SocialInput>(initial);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setErr(null);
    try {
      await onSubmit(form);
    } catch (e) {
      setErr(e instanceof Error ? e.message : "Kaydedilemedi");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center p-4 z-50">
      <form onSubmit={submit} className="bg-white rounded-lg w-full max-w-md">
        <div className="px-5 py-3 border-b border-slate-200 flex items-center justify-between">
          <h2 className="font-semibold">{title}</h2>
          <button type="button" onClick={onCancel} className="text-slate-500 text-2xl leading-none">
            ×
          </button>
        </div>
        <div className="p-5 grid grid-cols-1 sm:grid-cols-2 gap-4">
          <Field label="Etiket" value={form.label} onChange={(v) => setForm({ ...form, label: v })} hint="örn. Facebook, X, Instagram" />
          <Field label="Sıralama" type="number" value={String(form.sort_order)} onChange={(v) => setForm({ ...form, sort_order: Number(v) || 0 })} />
          <Field className="col-span-2" label="URL" value={form.url} onChange={(v) => setForm({ ...form, url: v })} hint="https://, mailto:, tel:" />
          <Field label="SF Symbol" value={form.system_icon} onChange={(v) => setForm({ ...form, system_icon: v })} hint='örn. "globe", "envelope.fill"' />
          <Field label="Renk (#RRGGBB)" value={form.tint_hex} onChange={(v) => setForm({ ...form, tint_hex: v })} />
        </div>
        {err && <div className="px-5 pb-2 text-red-600 text-sm">{err}</div>}
        <div className="px-5 py-3 border-t border-slate-200 flex justify-end gap-2">
          <button type="button" onClick={onCancel} className="px-3 py-1.5 border border-slate-300 rounded text-sm">
            Vazgeç
          </button>
          <button disabled={busy} type="submit" className="px-3 py-1.5 bg-brand-600 text-white rounded text-sm disabled:opacity-50">
            {busy ? "Kaydediliyor…" : "Kaydet"}
          </button>
        </div>
      </form>
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
  hint,
  type = "text",
  className = "",
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  hint?: string;
  type?: string;
  className?: string;
}) {
  return (
    <label className={`block ${className}`}>
      <div className="text-xs font-medium text-slate-600 mb-1">{label}</div>
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-full px-2.5 py-1.5 border border-slate-300 rounded text-sm"
      />
      {hint && <div className="text-xs text-slate-400 mt-0.5">{hint}</div>}
    </label>
  );
}
