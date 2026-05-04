/**
 * Tiny API client. Stores the JWT in localStorage.
 * Phase 1: email/password admin auth only. SIWA-on-web is Phase 2.
 */

const API_URL = import.meta.env.VITE_API_URL ?? "http://localhost:8000";
const TOKEN_KEY = "itt_admin_token";

export type Listing = {
  id: string;
  name: string;
  contact_person: string | null;
  directories: string[];
  kantons: string[];
  category: string | null;
  sub_category: string | null;
  address: string | null;
  phone: string | null;
  phone_public: boolean;
  email: string | null;
  email_public: boolean;
  website: string | null;
  description: string | null;
  image_url: string | null;
  status: "pending" | "active" | "rejected" | "suspended" | "expired" | "archived";
  package: string | null;
  paid_until: string | null;
  created_at: string;
  updated_at: string;
};

export type LoginResponse = {
  access_token: string;
  token_type: string;
  user_id: string;
  is_admin: boolean;
};

export type Event = {
  id: string;
  title: string;
  description: string | null;
  starts_at: string;
  ends_at: string | null;
  kanton: string;
  venue: string | null;
  address: string | null;
  image_url: string | null;
  status: "pending" | "active" | "rejected";
  created_at: string;
};

export type ContentPage = {
  slug: string;
  title: string;
  body_markdown: string;
  updated_at: string;
};

export const REJECTION_REASONS = [
  { code: "incomplete", label: "Eksik bilgi" },
  { code: "fraud", label: "Sahtecilik şüphesi" },
  { code: "duplicate", label: "Mükerrer kayıt" },
  { code: "inappropriate", label: "Uygunsuz içerik" },
  { code: "out_of_scope", label: "Kapsam dışı" },
  { code: "other", label: "Diğer" },
] as const;

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}
export function setToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token);
}
export function clearToken(): void {
  localStorage.removeItem(TOKEN_KEY);
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...((init.headers as Record<string, string>) || {}),
  };
  const token = getToken();
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await fetch(`${API_URL}${path}`, { ...init, headers });
  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`HTTP ${res.status}: ${detail}`);
  }
  if (res.status === 204) return undefined as unknown as T;
  return res.json();
}

export const api = {
  login: (email: string, password: string) =>
    request<LoginResponse>("/auth/email/login", {
      method: "POST",
      body: JSON.stringify({ email, password }),
    }),

  me: () => request<{ id: string; email: string; is_admin: boolean }>("/auth/me"),

  queue: (status: Listing["status"] = "pending") =>
    request<Listing[]>(`/admin/queue?status=${encodeURIComponent(status)}`),

  approve: (id: string) =>
    request<Listing>(`/admin/listings/${id}/approve`, { method: "POST" }),

  reject: (id: string, reason_code: string, notes?: string) =>
    request<Listing>(`/admin/listings/${id}/reject`, {
      method: "POST",
      body: JSON.stringify({ reason_code, notes: notes ?? null }),
    }),

  eventQueue: (status: Event["status"] = "pending") =>
    request<Event[]>(`/admin/events/queue?status=${encodeURIComponent(status)}`),

  approveEvent: (id: string) =>
    request<Event>(`/admin/events/${id}/approve`, { method: "POST" }),

  rejectEvent: (id: string) =>
    request<Event>(`/admin/events/${id}/reject`, { method: "POST" }),

  contentList: () => request<ContentPage[]>("/content"),

  contentGet: (slug: string) => request<ContentPage>(`/content/${slug}`),

  contentSave: (slug: string, title: string, body_markdown: string) =>
    request<ContentPage>(`/content/${slug}`, {
      method: "PUT",
      body: JSON.stringify({ title, body_markdown }),
    }),

  invoices: (unpaid: boolean = true) =>
    request<Invoice[]>(`/admin/invoices?unpaid=${unpaid}`),

  markPaid: (id: string, payment_method: "twint" | "bank") =>
    request<Invoice>(`/admin/invoices/${id}/mark-paid`, {
      method: "POST",
      body: JSON.stringify({ payment_method }),
    }),

  pushBroadcast: (
    title: string,
    body: string,
    category: "events" | "editorial" | "saved_search" | "my_listing",
    kanton: string | null
  ) =>
    request<{ sent: number; targeted: number }>("/admin/push/broadcast", {
      method: "POST",
      body: JSON.stringify({ title, body, category, kanton: kanton || null }),
    }),
};

export type Invoice = {
  id: string;
  listing_id: string;
  invoice_number: string;
  amount_chf: number;  // cents
  package: string;
  issued_at: string;
  due_at: string | null;
  paid_at: string | null;
  payment_method: "twint" | "bank" | null;
  pdf_url: string | null;
};
