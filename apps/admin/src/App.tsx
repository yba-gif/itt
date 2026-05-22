import { Navigate, NavLink, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import { useEffect, useState } from "react";

import Login from "./pages/Login";
import Queue from "./pages/Queue";
import ListingDetail from "./pages/ListingDetail";
import EventsQueue from "./pages/EventsQueue";
import ContentEditor from "./pages/ContentEditor";
import Payments from "./pages/Payments";
import PushComposer from "./pages/PushComposer";
import Users from "./pages/Users";
import AIQuestions from "./pages/AIQuestions";
import Consulates from "./pages/Consulates";
import Socials from "./pages/Socials";
import { clearToken, getToken } from "./api/client";

// Single source of truth for the nav — used by both the desktop inline bar
// and the mobile drawer so the two views can't drift out of sync.
const NAV_LINKS: { to: string; label: string }[] = [
  { to: "/queue?status=pending",  label: "İlanlar" },
  { to: "/events?status=pending", label: "Etkinlikler" },
  { to: "/payments",              label: "Ödemeler" },
  { to: "/push",                  label: "Bildirim" },
  { to: "/content",               label: "İçerik" },
  { to: "/consulates",            label: "Konsolosluk" },
  { to: "/socials",               label: "Sosyal" },
  { to: "/users",                 label: "Kullanıcılar" },
  { to: "/ai-questions",          label: "İTT AI" },
];

function Shell({ children }: { children: React.ReactNode }) {
  const navigate = useNavigate();
  const location = useLocation();
  const [drawerOpen, setDrawerOpen] = useState(false);

  // Close the mobile drawer whenever the route changes — otherwise the user
  // taps a link, the page transitions, but the drawer stays open over it.
  useEffect(() => { setDrawerOpen(false); }, [location.pathname, location.search]);

  const navItem    = "px-3 py-1.5 rounded text-sm hover:bg-white/10";
  const activeItem = "bg-white/15";
  // Drawer rows: taller tap targets, full-width, more contrast.
  const drawerItem   = "block px-4 py-3 text-base rounded hover:bg-white/10";
  const drawerActive = "bg-white/15";

  return (
    <div className="min-h-full">
      <header className="bg-brand-500 text-white px-4 md:px-6 py-3 flex items-center justify-between gap-3">
        <div className="flex items-center gap-4 md:gap-6 min-w-0">
          {/* Hamburger — only visible on small screens */}
          <button
            type="button"
            onClick={() => setDrawerOpen((v) => !v)}
            className="md:hidden p-1 -ml-1 rounded hover:bg-white/10"
            aria-label={drawerOpen ? "Menüyü kapat" : "Menüyü aç"}
            aria-expanded={drawerOpen}
          >
            {/* Inline SVG so we don't pull in an icon library */}
            {drawerOpen ? (
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M18 6 6 18M6 6l12 12" />
              </svg>
            ) : (
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M3 12h18M3 6h18M3 18h18" />
              </svg>
            )}
          </button>

          <NavLink to="/queue" className="font-semibold tracking-tight whitespace-nowrap">
            ITT-Rehber Admin
          </NavLink>

          {/* Desktop inline nav */}
          <nav className="hidden md:flex gap-1 text-sm">
            {NAV_LINKS.map((l) => (
              <NavLink
                key={l.to}
                to={l.to}
                end={l.to.startsWith("/queue")}
                className={({ isActive }) => `${navItem} ${isActive ? activeItem : ""}`}
              >
                {l.label}
              </NavLink>
            ))}
          </nav>
        </div>

        <button
          onClick={() => { clearToken(); navigate("/login"); }}
          className="text-sm opacity-90 hover:opacity-100 whitespace-nowrap"
        >
          Çıkış
        </button>
      </header>

      {/* Mobile drawer (overlay + sliding panel). The overlay catches taps
          outside the panel so users can dismiss without going back to the
          hamburger. */}
      {drawerOpen && (
        <div className="md:hidden fixed inset-0 z-40">
          <div
            className="absolute inset-0 bg-black/40"
            onClick={() => setDrawerOpen(false)}
            aria-hidden
          />
          <nav className="absolute top-0 left-0 bottom-0 w-72 max-w-[80vw] bg-brand-500 text-white shadow-xl overflow-y-auto pt-3 pb-6 px-3 space-y-1">
            {NAV_LINKS.map((l) => (
              <NavLink
                key={l.to}
                to={l.to}
                end={l.to.startsWith("/queue")}
                className={({ isActive }) => `${drawerItem} ${isActive ? drawerActive : ""}`}
              >
                {l.label}
              </NavLink>
            ))}
            <hr className="border-white/15 my-2" />
            <button
              onClick={() => { clearToken(); navigate("/login"); }}
              className={`${drawerItem} w-full text-left`}
            >
              Çıkış
            </button>
          </nav>
        </div>
      )}

      <main className="px-4 md:px-6 py-4 md:py-6 max-w-6xl mx-auto">{children}</main>
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
      <Route path="/consulates" element={<RequireAuth><Consulates /></RequireAuth>} />
      <Route path="/socials" element={<RequireAuth><Socials /></RequireAuth>} />
      <Route path="/users" element={<RequireAuth><Users /></RequireAuth>} />
      <Route path="/ai-questions" element={<RequireAuth><AIQuestions /></RequireAuth>} />
      <Route path="*" element={<Navigate to="/queue" replace />} />
    </Routes>
  );
}
