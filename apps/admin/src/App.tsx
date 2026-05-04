import { Navigate, NavLink, Route, Routes, useNavigate } from "react-router-dom";
import { useEffect, useState } from "react";

import Login from "./pages/Login";
import Queue from "./pages/Queue";
import ListingDetail from "./pages/ListingDetail";
import EventsQueue from "./pages/EventsQueue";
import ContentEditor from "./pages/ContentEditor";
import Payments from "./pages/Payments";
import PushComposer from "./pages/PushComposer";
import { clearToken, getToken } from "./api/client";

function Shell({ children }: { children: React.ReactNode }) {
  const navigate = useNavigate();
  const navItem = "px-3 py-1.5 rounded text-sm hover:bg-white/10";
  const activeItem = "bg-white/15";
  return (
    <div className="min-h-full">
      <header className="bg-brand-500 text-white px-6 py-3 flex items-center justify-between">
        <div className="flex items-center gap-6">
          <NavLink to="/queue" className="font-semibold tracking-tight">ITT-Rehber Admin</NavLink>
          <nav className="flex gap-1 text-sm">
            <NavLink to="/queue?status=pending" end className={({ isActive }) => `${navItem} ${isActive ? activeItem : ""}`}>İlanlar</NavLink>
            <NavLink to="/events?status=pending" className={({ isActive }) => `${navItem} ${isActive ? activeItem : ""}`}>Etkinlikler</NavLink>
            <NavLink to="/payments" className={({ isActive }) => `${navItem} ${isActive ? activeItem : ""}`}>Ödemeler</NavLink>
            <NavLink to="/push" className={({ isActive }) => `${navItem} ${isActive ? activeItem : ""}`}>Bildirim</NavLink>
            <NavLink to="/content" className={({ isActive }) => `${navItem} ${isActive ? activeItem : ""}`}>İçerik</NavLink>
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
      <Route path="/events" element={<RequireAuth><EventsQueue /></RequireAuth>} />
      <Route path="/payments" element={<RequireAuth><Payments /></RequireAuth>} />
      <Route path="/push" element={<RequireAuth><PushComposer /></RequireAuth>} />
      <Route path="/content" element={<RequireAuth><ContentEditor /></RequireAuth>} />
      <Route path="*" element={<Navigate to="/queue" replace />} />
    </Routes>
  );
}
