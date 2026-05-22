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

  getListing: (id: string) =>
    request<Listing>(`/admin/listings/${id}`),

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

  // ---- Users (Phase A admin endpoints) ----

  users: (opts: { page?: number; pageSize?: number; q?: string; adminsOnly?: boolean } = {}) => {
    const params = new URLSearchParams();
    params.set("page", String(opts.page ?? 1));
    params.set("page_size", String(opts.pageSize ?? 50));
    if (opts.q) params.set("q", opts.q);
    if (opts.adminsOnly) params.set("admins_only", "true");
    return request<UsersPage>(`/admin/users?${params.toString()}`);
  },

  setUserAdmin: (id: string, is_admin: boolean) =>
    request<UserRow>(`/admin/users/${id}`, {
      method: "PATCH",
      body: JSON.stringify({ is_admin }),
    }),

  // ---- AI question log ----

  aiQuestions: (opts: { page?: number; pageSize?: number } = {}) => {
    const params = new URLSearchParams();
    params.set("page", String(opts.page ?? 1));
    params.set("page_size", String(opts.pageSize ?? 50));
    return request<AIQuestionsPage>(`/admin/ai-questions?${params.toString()}`);
  },

  // ---- Consulates (Phase C admin) ----

  consulates: () => request<ConsulateRow[]>("/consulates"),
  createConsulate: (payload: ConsulateInput) =>
    request<ConsulateRow>("/admin/consulates", { method: "POST", body: JSON.stringify(payload) }),
  updateConsulate: (id: string, payload: ConsulateInput) =>
    request<ConsulateRow>(`/admin/consulates/${id}`, { method: "PUT", body: JSON.stringify(payload) }),
  deleteConsulate: (id: string) =>
    request<void>(`/admin/consulates/${id}`, { method: "DELETE" }),

  // ---- Socials (Phase C admin) ----

  socials: () => request<SocialRow[]>("/socials"),
  createSocial: (payload: SocialInput) =>
    request<SocialRow>("/admin/socials", { method: "POST", body: JSON.stringify(payload) }),
  updateSocial: (id: string, payload: SocialInput) =>
    request<SocialRow>(`/admin/socials/${id}`, { method: "PUT", body: JSON.stringify(payload) }),
  deleteSocial: (id: string) =>
    request<void>(`/admin/socials/${id}`, { method: "DELETE" }),
};

export type ConsulateRow = {
  id: string;
  city: string;
  title: string;
  address: string;
  phone: string;
  phone_display: string;
  email: string | null;
  website: string;
  hours_summary: string;
  hours_detail: string | null;
  consul_name: string | null;
  consul_title: string;
  consul_photo_url: string | null;
  sort_order: number;
  updated_at: string;
};

export type ConsulateInput = Omit<ConsulateRow, "id" | "updated_at">;

export type SocialRow = {
  id: string;
  label: string;
  system_icon: string;
  url: string;
  tint_hex: string;
  sort_order: number;
  updated_at: string;
};

export type SocialInput = Omit<SocialRow, "id" | "updated_at">;

export type UserRow = {
  id: string;
  email: string;
  display_name: string | null;
  is_admin: boolean;
  created_at: string;
};

export type UsersPage = {
  items: UserRow[];
  total: number;
  page: number;
  page_size: number;
};

export type AIQuestionRow = {
  id: string;
  user_id: string | null;
  question: string;
  response_chars: number;
  lang: string | null;
  created_at: string;
};

export type AIQuestionsPage = {
  items: AIQuestionRow[];
  total: number;
  page: number;
  page_size: number;
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
