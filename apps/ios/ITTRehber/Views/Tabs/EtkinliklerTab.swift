import SwiftUI
import EventKit

/// PRD §5.3: shows only events with starts_at >= now by default. Past events
/// surface in a "Geçmiş Etkinlikler" sub-tab.
struct EtkinliklerTab: View {
    @State private var mode: Mode = .upcoming
    @State private var selectedKanton: String = ""
    @State private var events: [Event] = []
    @State private var loading: Bool = false
    @State private var error: String?
    @State private var showSubmit: Bool = false

    enum Mode: Hashable { case upcoming, past }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mod", selection: $mode) {
                    Text("Yaklaşan").tag(Mode.upcoming)
                    Text("Geçmiş").tag(Mode.past)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.top, 8)

                kantonRow

                Group {
                    if loading && events.isEmpty {
                        ProgressView("Yükleniyor…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if events.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
            }
            .navigationTitle("Etkinlikler")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSubmit = true
                    } label: {
                        Label("Etkinlik Ekle", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showSubmit) {
                NavigationStack {
                    SubmitEventView { showSubmit = false; Task { await load() } }
                }
            }
            .task { await load() }
            .onChange(of: mode) { _, _ in Task { await load() } }
            .onChange(of: selectedKanton) { _, _ in Task { await load() } }
            .alert("Hata", isPresented: .constant(error != nil)) {
                Button("Tamam") { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    private var kantonRow: some View {
        Menu {
            Button("Tüm kantonlar", action: { selectedKanton = "" })
            Divider()
            ForEach(Kanton.all) { k in
                Button("\(k.code) — \(k.nameTR)") { selectedKanton = k.code }
            }
        } label: {
            HStack {
                Text(selectedKanton.isEmpty ? "Tüm kantonlar" : "Kanton: \(selectedKanton)")
                    .font(.subheadline)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text(mode == .upcoming ? "Yaklaşan etkinlik yok" : "Geçmiş etkinlik yok")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var list: some View {
        List {
            ForEach(events) { event in
                NavigationLink(destination: EventDetailView(event: event)) {
                    EventRow(event: event)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let resp = try await APIClient.shared.events(
                kanton: selectedKanton.isEmpty ? nil : selectedKanton,
                past: mode == .past
            )
            events = resp.items
        } catch let api as APIError {
            error = api.errorDescription
            events = []
        } catch {
            self.error = error.localizedDescription
            events = []
        }
    }
}

struct EventRow: View {
    let event: Event

    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Text(monthAbbr).font(.caption.bold()).foregroundStyle(.tint)
                Text(dayNum).font(.title3.bold())
            }
            .frame(width: 48)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.headline)
                Text("\(timeStr) • \(event.kanton)\(event.venue.map { " • \($0)" } ?? "")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var monthAbbr: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_CH")
        f.dateFormat = "MMM"
        return f.string(from: event.startsAt).uppercased()
    }

    private var dayNum: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_CH")
        f.dateFormat = "d"
        return f.string(from: event.startsAt)
    }

    private var timeStr: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_CH")
        f.timeStyle = .short
        return f.string(from: event.startsAt)
    }
}

struct EventDetailView: View {
    let event: Event
    @EnvironmentObject var push: PushManager
    @State private var reminderResult: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let urlString = event.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty: Color(.systemGray5)
                        case .success(let img): img.resizable().scaledToFill()
                        case .failure: Color(.systemGray5)
                        @unknown default: Color(.systemGray5)
                        }
                    }
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Text(event.title).font(.title2.bold())
                Text(formatted(event.startsAt))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let venue = event.venue {
                    Label(venue, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                }
                if let address = event.address {
                    Label(address, systemImage: "map")
                        .font(.subheadline)
                }

                Button {
                    Task { await scheduleReminder() }
                } label: {
                    Label("Hatırlatma kur (24 saat önce)", systemImage: "bell")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)

                if let reminderResult {
                    Text(reminderResult).font(.caption).foregroundStyle(.secondary)
                }

                if let description = event.description, !description.isEmpty {
                    Text("Açıklama").font(.headline).padding(.top, 4)
                    Text(description)
                }
            }
            .padding(16)
        }
        .navigationTitle("Etkinlik")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // PRD §5.9: contextual push permission ask — first time the user
            // views an event detail. Idempotent on subsequent visits.
            await push.requestAuthorizationIfNeeded()
        }
    }

    private func formatted(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_CH")
        f.dateStyle = .full
        f.timeStyle = .short
        return f.string(from: d)
    }

    private func scheduleReminder() async {
        let store = EKEventStore()
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await store.requestWriteOnlyAccessToEvents()
            } else {
                granted = try await withCheckedThrowingContinuation { cont in
                    store.requestAccess(to: .event) { ok, err in
                        if let err { cont.resume(throwing: err) } else { cont.resume(returning: ok) }
                    }
                }
            }
            guard granted else {
                reminderResult = "Takvim izni verilmedi."
                return
            }
            let ekEvent = EKEvent(eventStore: store)
            ekEvent.title = event.title
            ekEvent.startDate = event.startsAt
            ekEvent.endDate = event.endsAt ?? event.startsAt.addingTimeInterval(60 * 60)
            ekEvent.location = [event.venue, event.address].compactMap { $0 }.joined(separator: " — ")
            ekEvent.notes = event.description
            ekEvent.alarms = [EKAlarm(relativeOffset: -60 * 60 * 24)]
            ekEvent.calendar = store.defaultCalendarForNewEvents
            try store.save(ekEvent, span: .thisEvent)
            reminderResult = "Takvime eklendi. 24 saat öncesinde hatırlatma kuruldu."
        } catch {
            reminderResult = "Hatırlatma kurulamadı: \(error.localizedDescription)"
        }
    }
}

struct SubmitEventView: View {
    let onDone: () -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var startsAt = Date().addingTimeInterval(60 * 60 * 24)
    @State private var kanton = "ZH"
    @State private var venue = ""
    @State private var address = ""
    @State private var submitterEmail = ""
    @State private var busy = false
    @State private var error: String?
    @State private var showSuccess = false

    var body: some View {
        Form {
            Section("Etkinlik") {
                TextField("Başlık", text: $title)
                DatePicker("Başlangıç", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                Picker("Kanton", selection: $kanton) {
                    ForEach(Kanton.all) { k in Text(k.code).tag(k.code) }
                }
                TextField("Mekan", text: $venue)
                TextField("Adres", text: $address)
            }
            Section("İletişim (yalnızca moderatöre)") {
                TextField("E-posta", text: $submitterEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section {
                TextField("Açıklama", text: $description, axis: .vertical).lineLimit(3...6)
            }
            if let error {
                Section { Text(error).foregroundStyle(.red) }
            }
            Section {
                Button(action: submit) {
                    if busy { ProgressView() } else {
                        Text("Gönder").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty || busy)
            } footer: {
                Text("Etkinlikler yayınlanmadan önce yönetici onayından geçer.")
            }
        }
        .navigationTitle("Etkinlik Ekle")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Gönderildi", isPresented: $showSuccess) {
            Button("Tamam") { onDone() }
        } message: { Text("Etkinlik incelemeye alındı.") }
    }

    private func submit() {
        Task {
            busy = true
            error = nil
            defer { busy = false }
            do {
                _ = try await APIClient.shared.submitEvent(EventSubmitInput(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    startsAt: startsAt,
                    endsAt: nil,
                    kanton: kanton,
                    venue: venue.isEmpty ? nil : venue,
                    address: address.isEmpty ? nil : address,
                    imageURL: nil,
                    submitterEmail: submitterEmail.isEmpty ? nil : submitterEmail
                ))
                showSuccess = true
            } catch {
                self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
