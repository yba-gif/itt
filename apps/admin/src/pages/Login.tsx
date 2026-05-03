import { useState } from "react";
import { useNavigate } from "react-router-dom";

import { api, setToken } from "../api/client";

export default function Login() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const { access_token, is_admin } = await api.login(email, password);
      if (!is_admin) {
        setError("Bu hesap admin yetkisine sahip değil.");
        return;
      }
      setToken(access_token);
      navigate("/queue");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Giriş başarısız");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-50 p-4">
      <form onSubmit={onSubmit} className="bg-white shadow rounded-lg p-8 w-full max-w-md">
        <h1 className="text-xl font-semibold mb-1">ITT-Rehber Admin</h1>
        <p className="text-sm text-slate-500 mb-6">Yönetici hesabıyla giriş yapın.</p>

        <label className="block text-sm font-medium mb-1" htmlFor="email">E-posta</label>
        <input
          id="email"
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="w-full border rounded px-3 py-2 mb-4 focus:outline-none focus:ring-2 focus:ring-brand-500"
        />

        <label className="block text-sm font-medium mb-1" htmlFor="password">Parola</label>
        <input
          id="password"
          type="password"
          required
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="w-full border rounded px-3 py-2 mb-6 focus:outline-none focus:ring-2 focus:ring-brand-500"
        />

        {error && <div className="text-sm text-red-600 mb-4">{error}</div>}

        <button
          type="submit"
          disabled={busy}
          className="w-full bg-brand-500 hover:bg-brand-600 disabled:opacity-60 text-white py-2 rounded font-medium"
        >
          {busy ? "Giriş yapılıyor…" : "Giriş yap"}
        </button>
      </form>
    </div>
  );
}
