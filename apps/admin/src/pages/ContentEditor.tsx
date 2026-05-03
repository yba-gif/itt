import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useState } from "react";

import { api, type ContentPage } from "../api/client";

export default function ContentEditor() {
  const qc = useQueryClient();
  const { data: pages, isLoading } = useQuery({
    queryKey: ["content"],
    queryFn: () => api.contentList(),
  });
  const [activeSlug, setActiveSlug] = useState<string | null>(null);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [savedAt, setSavedAt] = useState<string | null>(null);

  useEffect(() => {
    if (!activeSlug && pages && pages.length > 0) {
      pickPage(pages[0]);
    }
  }, [pages]);

  function pickPage(p: ContentPage) {
    setActiveSlug(p.slug);
    setTitle(p.title);
    setBody(p.body_markdown);
    setSavedAt(null);
  }

  const save = useMutation({
    mutationFn: () => api.contentSave(activeSlug!, title, body),
    onSuccess: (page) => {
      setSavedAt(new Date().toLocaleTimeString("tr-TR"));
      qc.invalidateQueries({ queryKey: ["content"] });
      qc.setQueryData<ContentPage>(["content", page.slug], page);
    },
  });

  if (isLoading) return <div className="text-slate-500">Yükleniyor…</div>;

  return (
    <div className="grid grid-cols-1 md:grid-cols-[220px_1fr] gap-6">
      <aside className="bg-white border rounded">
        <div className="px-4 py-2 text-xs uppercase text-slate-400">Sayfalar</div>
        <ul className="divide-y">
          {pages?.map((p) => (
            <li key={p.slug}>
              <button
                onClick={() => pickPage(p)}
                className={
                  "w-full text-left px-4 py-2 hover:bg-slate-50 " +
                  (activeSlug === p.slug ? "bg-slate-50 font-medium" : "")
                }
              >
                {p.title}
                <div className="text-xs text-slate-400">{p.slug}</div>
              </button>
            </li>
          ))}
        </ul>
      </aside>
      <section className="bg-white border rounded p-4">
        {activeSlug ? (
          <>
            <label className="block text-sm font-medium mb-1">Başlık</label>
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full border rounded px-3 py-2 mb-3"
            />
            <label className="block text-sm font-medium mb-1">İçerik (Markdown)</label>
            <textarea
              value={body}
              onChange={(e) => setBody(e.target.value)}
              className="w-full border rounded px-3 py-2 mb-3 h-96 font-mono text-sm"
            />
            <div className="flex items-center gap-3">
              <button
                onClick={() => save.mutate()}
                disabled={save.isPending}
                className="bg-brand-500 hover:bg-brand-600 disabled:opacity-60 text-white px-4 py-2 rounded"
              >
                {save.isPending ? "Kaydediliyor…" : "Kaydet"}
              </button>
              {savedAt && (
                <span className="text-sm text-emerald-700">{savedAt} kaydedildi</span>
              )}
              {save.error && (
                <span className="text-sm text-red-600">Hata: {String(save.error)}</span>
              )}
            </div>
          </>
        ) : (
          <div className="text-slate-500">Bir sayfa seçin.</div>
        )}
      </section>
    </div>
  );
}
