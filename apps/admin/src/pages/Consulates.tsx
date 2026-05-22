import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { api, type ConsulateRow, type ConsulateInput } from "../api/client";

const blankInput: ConsulateInput = {
  city: "",
  title: "",
  address: "",
  phone: "",
  phone_display: "",
  email: null,
  website: "https://",
  hours_summary: "Pzt - Cuma\n09:00 - 12:00 / 13:00 - 18:00",
  hours_detail: null,
  consul_name: null,
  consul_title: "",
  consul_photo_url: null,
  sort_order: 100,
};

export default function Consulates() {
  const queryClient = useQueryClient();
  const { data, isLoading, error } = useQuery({
    queryKey: ["consulates"],
    queryFn: api.consulates,
  });

  const [editing, setEditing] = useState<ConsulateRow | null>(null);
  const [creating, setCreating] = useState(false);

  function invalidate() {
    queryClient.invalidateQueries({ queryKey: ["consulates"] });
  }

  const removeM = useMutation({
    mutationFn: api.deleteConsulate,
    onSuccess: invalidate,
  });

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-xl font-semibold">
          Konsolosluklar{data && ` (${data.length})`}
        </h1>
        <button
          onClick={() => setCreating(true)}
          className="px-3 py-1.5 bg-brand-600 text-white rounded text-sm hover:bg-brand-700"
        >
          + Yeni
        </button>
      </div>

      {isLoading && <div className="text-slate-500">Yükleniyor…</div>}
      {error && <div className="text-red-600">Hata: {String(error)}</div>}

      {data && data.length === 0 && !creating && (
        <div className="bg-white border border-slate-200 rounded p-6 text-slate-500 text-center">
          Henüz konsolosluk yok. Yukarıdaki + Yeni'ye dokunarak ekleyin.
        </div>
      )}

      <div className="space-y-3">
        {data?.map((c) => (
          <div key={c.id} className="bg-white border border-slate-200 rounded p-4">
            <div className="flex items-start gap-3">
              {c.consul_photo_url ? (
                /* eslint-disable-next-line @next/next/no-img-element */
                <img
                  src={c.consul_photo_url}
                  alt={c.consul_name ?? c.consul_title}
                  className="w-14 h-14 rounded-full object-cover border border-slate-200"
                />
              ) : (
                <div className="w-14 h-14 rounded-full bg-slate-100 flex items-center justify-center text-slate-400 text-xl">
                  👤
                </div>
              )}
              <div className="flex-1 min-w-0">
                <div className="font-semibold text-slate-800">
                  {c.city} <span className="text-slate-400 font-normal">·</span>{" "}
                  <span className="text-sm text-slate-600 font-normal">{c.title}</span>
                </div>
                <div className="text-xs text-slate-500 mt-0.5">
                  {c.consul_name ?? "—"} · {c.consul_title}
                </div>
                <div className="text-xs text-slate-500 mt-1">{c.address}</div>
                <div className="text-xs text-slate-500">
                  {c.phone_display} · {c.email ?? "(no email)"}
                </div>
              </div>
              <div className="flex gap-2 text-sm">
                <button
                  onClick={() => setEditing(c)}
                  className="px-2.5 py-1 border border-slate-300 rounded hover:bg-slate-50"
                >
                  Düzenle
                </button>
                <button
                  onClick={() => {
                    if (window.confirm(`${c.city} konsolosluğunu silmek istediğinize emin misiniz?`)) {
                      removeM.mutate(c.id);
                    }
                  }}
                  className="px-2.5 py-1 border border-red-300 text-red-700 rounded hover:bg-red-50"
                >
                  Sil
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {creating && (
        <ConsulateForm
          initial={blankInput}
          title="Yeni konsolosluk"
          onCancel={() => setCreating(false)}
          onSubmit={async (payload) => {
            await api.createConsulate(payload);
            setCreating(false);
            invalidate();
          }}
        />
      )}
      {editing && (
        <ConsulateForm
          initial={consulateToInput(editing)}
          title={`${editing.city} düzenle`}
          onCancel={() => setEditing(null)}
          onSubmit={async (payload) => {
            await api.updateConsulate(editing.id, payload);
            setEditing(null);
            invalidate();
          }}
        />
      )}
    </div>
  );
}

function consulateToInput(c: ConsulateRow): ConsulateInput {
  // Strip id + updated_at
  const { id: _id, updated_at: _u, ...rest } = c;
  return rest;
}

// --- Form (used for both create and edit) ----------------------------------

function ConsulateForm({
  initial,
  title,
  onCancel,
  onSubmit,
}: {
  initial: ConsulateInput;
  title: string;
  onCancel: () => void;
  onSubmit: (payload: ConsulateInput) => Promise<void>;
}) {
  const [form, setForm] = useState<ConsulateInput>(initial);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  function update<K extends keyof ConsulateInput>(key: K, value: ConsulateInput[K]) {
    setForm((f) => ({ ...f, [key]: value }));
  }

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
      <form
        onSubmit={submit}
        className="bg-white rounded-lg w-full max-w-2xl max-h-[90vh] overflow-y-auto"
      >
        <div className="px-5 py-3 border-b border-slate-200 flex items-center justify-between sticky top-0 bg-white">
          <h2 className="font-semibold">{title}</h2>
          <button type="button" onClick={onCancel} className="text-slate-500 text-2xl leading-none">
            ×
          </button>
        </div>
        <div className="p-5 grid grid-cols-2 gap-4">
          <Field label="Şehir" value={form.city} onChange={(v) => update("city", v)} />
          <Field label="Sıralama" type="number" value={String(form.sort_order)} onChange={(v) => update("sort_order", Number(v) || 0)} />
          <Field className="col-span-2" label="Başlık" value={form.title} onChange={(v) => update("title", v)} />
          <Field className="col-span-2" label="Adres" value={form.address} onChange={(v) => update("address", v)} />
          <Field label="Telefon (E.164)" value={form.phone} onChange={(v) => update("phone", v)} hint="örn. +41313592200" />
          <Field label="Telefon (gösterim)" value={form.phone_display} onChange={(v) => update("phone_display", v)} hint="örn. +41 31 359 22 00" />
          <Field label="E-posta" value={form.email ?? ""} onChange={(v) => update("email", v || null)} optional />
          <Field label="Web sitesi" value={form.website} onChange={(v) => update("website", v)} />
          <Field className="col-span-2" label="Çalışma saatleri (özet)" value={form.hours_summary} multiline onChange={(v) => update("hours_summary", v)} />
          <Field className="col-span-2" label="Çalışma saatleri (detay)" value={form.hours_detail ?? ""} multiline optional onChange={(v) => update("hours_detail", v || null)} />
          <Field label="Konsolos adı" value={form.consul_name ?? ""} onChange={(v) => update("consul_name", v || null)} optional />
          <Field label="Konsolos ünvanı" value={form.consul_title} onChange={(v) => update("consul_title", v)} hint="örn. T.C. Bern Büyükelçisi" />
          <Field className="col-span-2" label="Konsolos foto URL" value={form.consul_photo_url ?? ""} onChange={(v) => update("consul_photo_url", v || null)} optional />
        </div>

        {err && <div className="px-5 pb-2 text-red-600 text-sm">{err}</div>}

        <div className="px-5 py-3 border-t border-slate-200 flex justify-end gap-2 sticky bottom-0 bg-white">
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
  multiline,
  optional,
  className = "",
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  hint?: string;
  type?: string;
  multiline?: boolean;
  optional?: boolean;
  className?: string;
}) {
  return (
    <label className={`block ${className}`}>
      <div className="text-xs font-medium text-slate-600 mb-1">
        {label} {optional && <span className="text-slate-400 font-normal">(opsiyonel)</span>}
      </div>
      {multiline ? (
        <textarea
          rows={2}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          className="w-full px-2.5 py-1.5 border border-slate-300 rounded text-sm font-mono"
        />
      ) : (
        <input
          type={type}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          className="w-full px-2.5 py-1.5 border border-slate-300 rounded text-sm"
        />
      )}
      {hint && <div className="text-xs text-slate-400 mt-0.5">{hint}</div>}
    </label>
  );
}
