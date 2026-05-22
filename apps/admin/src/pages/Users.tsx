import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { api, type UserRow } from "../api/client";

const PAGE_SIZE = 50;

export default function Users() {
  const [page, setPage] = useState(1);
  const [q, setQ] = useState("");
  const [adminsOnly, setAdminsOnly] = useState(false);

  const queryClient = useQueryClient();

  const { data, isLoading, error } = useQuery({
    queryKey: ["users", page, q, adminsOnly],
    queryFn: () => api.users({ page, pageSize: PAGE_SIZE, q: q.trim() || undefined, adminsOnly }),
  });

  const toggle = useMutation({
    mutationFn: ({ id, isAdmin }: { id: string; isAdmin: boolean }) =>
      api.setUserAdmin(id, isAdmin),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["users"] }),
  });

  const totalPages = data ? Math.max(1, Math.ceil(data.total / PAGE_SIZE)) : 1;

  return (
    <div>
      <h1 className="text-xl font-semibold mb-4">
        Kullanıcılar{data && ` (${data.total})`}
      </h1>

      <div className="bg-white border border-slate-200 rounded p-3 mb-4 flex flex-wrap gap-2 items-center">
        <input
          type="text"
          value={q}
          onChange={(e) => { setQ(e.target.value); setPage(1); }}
          placeholder="E-posta veya ad ara…"
          className="flex-1 min-w-[200px] px-3 py-1.5 border border-slate-300 rounded text-sm"
        />
        <label className="flex items-center gap-1.5 text-sm text-slate-700">
          <input
            type="checkbox"
            checked={adminsOnly}
            onChange={(e) => { setAdminsOnly(e.target.checked); setPage(1); }}
          />
          Sadece adminler
        </label>
      </div>

      {isLoading && <div className="text-slate-500">Yükleniyor…</div>}
      {error && <div className="text-red-600">Hata: {String(error)}</div>}

      {data && data.items.length === 0 && (
        <div className="bg-white border border-slate-200 rounded p-6 text-slate-500 text-center">
          Eşleşen kullanıcı yok.
        </div>
      )}

      {data && data.items.length > 0 && (
        <div className="bg-white border border-slate-200 rounded overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="text-left px-4 py-2.5 font-medium">E-posta</th>
                <th className="text-left px-4 py-2.5 font-medium">Ad</th>
                <th className="text-left px-4 py-2.5 font-medium">Kayıt</th>
                <th className="text-left px-4 py-2.5 font-medium">Rol</th>
                <th className="px-4 py-2.5"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {data.items.map((u) => (
                <UserRowEl
                  key={u.id}
                  user={u}
                  onToggle={(isAdmin) => toggle.mutate({ id: u.id, isAdmin })}
                  pending={toggle.isPending}
                />
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

function UserRowEl({
  user,
  onToggle,
  pending,
}: {
  user: UserRow;
  onToggle: (isAdmin: boolean) => void;
  pending: boolean;
}) {
  const [showConfirm, setShowConfirm] = useState(false);

  const confirmText = user.is_admin
    ? `"${user.email}" kullanıcısının admin yetkisini kaldırmak istediğinize emin misiniz?`
    : `"${user.email}" kullanıcısına admin yetkisi vermek istediğinize emin misiniz?`;

  return (
    <tr className="hover:bg-slate-50">
      <td className="px-4 py-2.5 text-slate-800">{user.email}</td>
      <td className="px-4 py-2.5 text-slate-600">{user.display_name ?? "—"}</td>
      <td className="px-4 py-2.5 text-slate-500">
        {new Date(user.created_at).toLocaleDateString("tr-CH")}
      </td>
      <td className="px-4 py-2.5">
        {user.is_admin ? (
          <span className="inline-flex items-center px-2 py-0.5 bg-brand-100 text-brand-700 rounded text-xs font-semibold">
            Admin
          </span>
        ) : (
          <span className="text-slate-500 text-xs">Kullanıcı</span>
        )}
      </td>
      <td className="px-4 py-2.5 text-right">
        {showConfirm ? (
          <div className="inline-flex gap-1.5">
            <button
              disabled={pending}
              onClick={() => { onToggle(!user.is_admin); setShowConfirm(false); }}
              className="px-2.5 py-1 bg-red-600 text-white rounded text-xs disabled:opacity-50"
            >
              Onayla
            </button>
            <button
              onClick={() => setShowConfirm(false)}
              className="px-2.5 py-1 border border-slate-300 rounded text-xs"
            >
              Vazgeç
            </button>
          </div>
        ) : (
          <button
            onClick={() => {
              if (window.confirm(confirmText)) onToggle(!user.is_admin);
            }}
            className="text-brand-600 hover:underline text-xs"
          >
            {user.is_admin ? "Admin yetkisini kaldır" : "Admin yap"}
          </button>
        )}
      </td>
    </tr>
  );
}
