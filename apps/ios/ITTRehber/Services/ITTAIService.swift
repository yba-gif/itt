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

    private let model = "gemini-1.5-flash"

    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String ?? ""
    }

    // MARK: - System Prompt
    // TODO: Replace placeholder with full TGS-ITT knowledge base when provided.
    private let systemPrompt = """
    Sen TGS-ITT Rehber uygulamasının yapay zeka asistanısın. TGS-ITT, İsviçre'deki Türk kökenli topluluğa hizmet eden kapsamlı bir rehber ve topluluk platformudur.

    Yardımcı olduğun konular:
    - Sağlık: doktor, aile hekimi, hastane, sağlık sigortası (Krankenkasse), ilaç ve eczane
    - Hukuk: oturum izni (B/C Ausweis), vatandaşlık başvurusu, çalışma izni, kira hukuku, boşanma
    - Eğitim: okul kaydı, Almanca/Fransızca dil kursları, destek dersleri (Nachhilfe), üniversite
    - Finans: vergi beyannamesi, AHV/AVS emeklilik sigortası, banka hesabı, ev kredisi
    - İş dünyası: GmbH/AG kurma, serbest meslek, girişimcilik destekleri
    - Tercüme: belge tercümesi, resmi kurum çevirmenliği
    - Topluluk: TGS-ITT etkinlikleri, kanton bazlı aktiviteler, cemaat haberleri
    - Kanton işlemleri: ikametgâh değişikliği, pasaport/kimlik yenileme, araç tescili

    Üslup kuralları:
    - Sıcak, samimi ve doğrudan ol
    - Kısa cevaplar tercih et (2-4 cümle); gerçekten karmaşık konularda daha uzun ol
    - Mümkünse somut adımlar ver ("1. … 2. … 3. …" formatı kullan)
    - Kullanıcı Türkçe yazarsa Türkçe, Almanca yazarsa Almanca, başka dil kullanırsa o dilde cevap ver
    - Kesin hukuki veya tıbbi tavsiye vermekten kaçın; "Bir uzmana danışmanızı öneririm" de
    - TGS-ITT rehberindeki uzmanları önermek için "Rehber > [Kategori] bölümüne bakabilirsiniz" de
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

        guard !apiKey.isEmpty else {
            updateMessage(id: assistantID, text: "API anahtarı yapılandırılmamış. Lütfen geliştiriciye bildirin.")
            return
        }

        do {
            let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?key=\(apiKey)&alt=sse"
            guard let url = URL(string: endpoint) else { return }

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 30

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
