import { Navigate, Route, Routes, Link, useNavigate } from "react-router-dom";
import { useEffect, useState } from "react";

import Login from "./pages/Login";
import Queue from "./pages/Queue";
import ListingDetail from "./pages/ListingDetail";
import { clearToken, getToken } from "./api/client";

function Shell({ children }: { children: React.ReactNode }) {
  const navigate = useNavigate();
  return (
    <div className="min-h-full">
      <header className="bg-brand-500 text-white px-6 py-3 flex items-center justify-between">
        <div className="flex items-center gap-6">
          <Link to="/queue" className="font-semibold tracking-tight">ITT-Rehber Admin</Link>
          <nav className="flex gap-4 text-sm opacity-90">
            <Link to="/queue?status=pending" className="hover:opacity-100">Beklemede</Link>
            <Link to="/queue?status=active" className="hover:opacity-100">Yayında</Link>
            <Link to="/queue?status=suspended" className="hover:opacity-100">Askıya alınan</Link>
          </nav>
        </div>
        <button
          onClick={() => { clearToken(); navigate("/login"); }}
          className="text-sm opacity-90 hover:opacity-100"
        >
          Çıkış
        </button>
      </header>
      <main className="px-6 py-6 max-w-6xl mx-auto">{children}</main>
    </div>
  );
}

function RequireAuth({ children }: { children: React.ReactNode }) {
  const [hasToken, setHasToken] = useState<boolean | null>(null);
  useEffect(() => { setHasToken(!!getToken()); }, []);
  if (hasToken === null) return null;
  if (!hasToken) return <Navigate to="/login" replace />;
  return <Shell>{children}</Shell>;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/queue" element={<RequireAuth><Queue /></RequireAuth>} />
      <Route path="/listings/:id" element={<RequireAuth><ListingDetail /></RequireAuth>} />
      <Route path="*" element={<Navigate to="/queue" replace />} />
    </Routes>
  );
}
