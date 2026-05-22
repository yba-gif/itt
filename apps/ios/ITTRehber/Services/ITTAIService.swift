import Foundation

// MARK: - İTT AI Service
// Direct Gemini API client — conversations stay on-device, never touch ITT backend.

@MainActor
final class ITTAIService: ObservableObject {
    static let shared = ITTAIService()
    private init() {}

    @Published var messages: [AIMessage] = []
    @Published var isStreaming: Bool = false
    @Published var error: String?

    // MARK: - System Prompt
    private let systemPrompt = """
    Sen İTT Rehber uygulamasının yapay zeka asistanısın. İTT Rehber, TGS-ITT (Türkische Gemeinschaft Schweiz / İsviçre Türk Toplumu) tarafından sunulan, İsviçre'deki Türk topluluğuna özel bir rehber uygulamasıdır.

    KAPSAM — SADECE aşağıdaki konularda yardım et:
    - İTT Rehber uygulaması: nasıl kullanılır, kategoriler, hizmet ekleme
    - Sağlık: doktor, aile hekimi, hastane, Krankenkasse, eczane — Rehber > Sağlık
    - Hukuk & İdare: oturum izni (B/C/L Ausweis), vatandaşlık, çalışma izni, kira, boşanma — Rehber > Hukuk
    - Eğitim: okul kaydı, dil kursları, destek dersleri (Nachhilfe) — Rehber > Okullar & Destek Dersi
    - Finans: vergi beyannamesi, AHV/AVS, pillar 3a, banka, kredi — Rehber > Finans
    - İşletme & Girişimcilik: GmbH/AG kurma, serbest meslek — Rehber > İşletme
    - Tercüme & Noterlik — Rehber > Tercüme
    - Meslek & Kariyer — Rehber > Meslek
    - Camiler & Dini Hizmetler — Rehber > Camiler
    - TGS-ITT Mezunlar Ağı — Rehber > Mezunlar
    - Konsolosluklar: Bern Büyükelçiliği (+41 31 359 22 00), Zürich Başkonsolosluğu (+41 44 201 64 00), Cenevre Başkonsolosluğu (+41 22 732 16 00)
    - TGS-ITT etkinlikleri, haberler, topluluk bilgileri
    - İsviçre'de günlük yaşam: ulaşım, SBB, konut, ikametgâh tescili, belediye işlemleri

    KAPSAM DIŞI — Aşağıdaki konularda YARDIM ETME, kibarca reddet:
    - Türkiye'ye veya başka ülkelere özgü konular (İsviçre ile ilgisi yoksa)
    - Genel dünya haberleri, siyaset, eğlence, spor
    - Yazılım geliştirme, matematik, bilim (İsviçre/ITT bağlantısı yoksa)
    - Herhangi bir zararlı, yasadışı veya etik dışı içerik

    ÜSLUP:
    - Sıcak, samimi, doğrudan ve kısa ol (2-4 cümle yeterli; karmaşık konularda biraz daha uzun olabilirsin)
    - Somut adımlar ver: "1. … 2. … 3. …" formatını kullan
    - Kullanıcı Türkçe → Türkçe, Almanca → Almanca, Fransızca → Fransızca, İngilizce → İngilizce yanıt ver
    - Hukuki/tıbbi kesin tavsiye verme; "Bir uzmanla görüşmenizi öneririm" de
    - Kapsam dışı sorularda: "Bu konuda yardımcı olamıyorum; İTT AI yalnızca İsviçre'deki Türk topluluğuna yönelik konularda destek verir." de

    YÖNLENDİRME — ÇOK ÖNEMLİ:
    Kullanıcının sorusu bir Rehber kategorisine karşılık geliyorsa, cevabının SONUNA tek satır Markdown link ekle. Kullanıcı bu linke dokununca uygulama doğrudan o kategoriyi açar. Format:

        [Kategori adı →](itt://directory/KOD)

    Kategori kodları:
    - saglik       → doktor, diş hekimi, fizyoterapi, eczane, Krankenkasse
    - hukuk        → avukat, oturum izni, çalışma izni, vatandaşlık, dava
    - okullar      → okul kaydı, dil kursu (Deutsch/Français)
    - destek_dersi → çocuk için Türkçe dersi, Nachhilfe
    - finans       → vergi, mali müşavir, AHV/AVS, pillar 3a, banka, kredi
    - isletme      → şirket kurma (GmbH/AG/Einzelfirma), serbest meslek
    - tercume      → noter onaylı tercüme, yeminli tercüman
    - meslek       → meslek yönlendirme, kariyer danışmanlığı
    - camiler      → cami, imam, dini hizmet
    - mezunlar     → TGS-ITT mezunlar ağı

    Üst seviye sekme linkleri:
    - itt://tab/etkinlikler  → TGS-ITT etkinlikleri sekmesi
    - itt://tab/bilgi        → Konsolosluk + acil durum bilgileri

    Örnekler:
    - "İsviçre'de avukat arıyorum" → cevabın sonunda: [Türkçe avukat ara →](itt://directory/hukuk)
    - "Doktor lazım" → [Türkçe konuşan doktor →](itt://directory/saglik)
    - "Şirket kurmak istiyorum" → [İşletme rehberi →](itt://directory/isletme)
    - "Çocuğum için Türkçe ders" → [Destek dersi →](itt://directory/destek_dersi)
    - "Acil numara" → [Konsolosluk & acil →](itt://tab/bilgi)

    Birden fazla kategori uygunsa en alakalı OLAN BİR TANE link ekle, fazlasını ekleme. Kapsam dışı veya genel sohbet sorularda LİNK EKLEME.
    """

    // MARK: - Send Message

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isStreaming else { return }

        error = nil
        messages.append(AIMessage(role: .user, text: trimmed))

        let assistantID = UUID()
        messages.append(AIMessage(id: assistantID, role: .assistant, text: ""))

        isStreaming = true
        defer { isStreaming = false }

        do {
            // All requests go through the ITT backend proxy — API key stays server-side.
            let proxyURL = APIClient.shared.baseURL.appendingPathComponent("ai/chat")

            var req = URLRequest(url: proxyURL)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 45

            // Build conversation history — exclude the empty assistant placeholder at end
            let contents: [[String: Any]] = messages.dropLast().map { msg in
                [
                    "role": msg.role == .user ? "user" : "model",
                    "parts": [["text": msg.text]]
                ]
            }

            let body: [String: Any] = [
                "system_instruction": ["parts": [["text": systemPrompt]]],
                "contents": contents,
                "generationConfig": [
                    "temperature": 0.8,
                    "maxOutputTokens": 1024,
                    "topP": 0.95
                ]
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            var accumulated = ""
            let (bytes, _) = try await URLSession.shared.bytes(for: req)

            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let jsonStr = String(line.dropFirst(6))
                guard jsonStr != "[DONE]",
                      let data = jsonStr.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let content = candidates.first?["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]],
                      let chunk = parts.first?["text"] as? String
                else { continue }

                accumulated += chunk
                updateMessage(id: assistantID, text: accumulated)
            }

            if accumulated.isEmpty {
                updateMessage(id: assistantID, text: "Şu anda yanıt alamadım. Lütfen tekrar deneyin.")
            }

        } catch let err as NSError {
            let msg = err.code == NSURLErrorTimedOut
                ? "İstek zaman aşımına uğradı. İnternet bağlantınızı kontrol edin."
                : "Bağlantı hatası: \(err.localizedDescription)"
            updateMessage(id: assistantID, text: msg)
            self.error = err.localizedDescription
        }
    }

    func clear() {
        messages = []
        error = nil
    }

    // MARK: - Helpers

    private func updateMessage(id: UUID, text: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].text = text
    }
}

// MARK: - AIMessage

struct AIMessage: Identifiable {
    let id: UUID
    enum Role { case user, assistant }
    let role: Role
    var text: String

    init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}
