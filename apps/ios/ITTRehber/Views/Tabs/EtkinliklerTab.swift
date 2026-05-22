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
                .padding(.horizontal, TGSSpacing.md)
                .padding(.top, TGSSpacing.sm + 2)
                .padding(.bottom, TGSSpacing.xs)

                kantonRow

                Group {
                    if loading && events.isEmpty {
                        // P2-1: skeleton rows during first load
                        List {
                            ForEach(0..<5, id: \.self) { _ in
                                ListingRowSkeleton()
                                    .listRowBackground(Color.white)
                                    .listRowSeparatorTint(Color.tgsBorder)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.tgsCream)
                        .allowsHitTesting(false)
                    } else if let err = error, events.isEmpty {
                        // P2-5: inline error when list is empty
                        ErrorStateView(message: err) {
                            error = nil; Task { await load() }
                        }
                    } else if events.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
            }
            .background(Color.tgsCream)
            .navigationTitle("Etkinlikler")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
            .tgsOnChange(of: mode) { Task { await load() } }
            .tgsOnChange(of: selectedKanton) { Task { await load() } }
            // P2-5: alert only fires when list has content (inline handles empty case)
            .alert("Hata", isPresented: .constant(error != nil && !events.isEmpty)) {
                Button("Tekrar Dene") { error = nil; Task { await load() } }
                Button("Kapat", role: .cancel) { error = nil }
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
                    .foregroundStyle(Color.tgsCharcoal)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(Color.tgsMuted)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.tgsSurface)
                    .frame(width: 80, height: 80)
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.tgsMuted)
            }
            Text(mode == .upcoming ? "Yaklaşan etkinlik yok" : "Geçmiş etkinlik yok")
                .font(.headline)
                .foregroundStyle(Color.tgsCharcoal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tgsCream)
    }

    // P2-6: group events into relative time buckets
    private enum DateGroup: String, CaseIterable {
        case thisWeek   = "Bu Hafta"
        case nextWeek   = "Gelecek Hafta"
        case thisMonth  = "Bu Ay"
        case later      = "Daha Sonra"
        case past       = "Geçmiş"
    }

    private func dateGroup(for event: Event) -> DateGroup {
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let startOfNextWeek = cal.date(byAdding: .weekOfYear, value: 1, to: cal.startOfDay(for: now))!
        let startOfWeekAfterNext = cal.date(byAdding: .weekOfYear, value: 2, to: startOfToday)!
        let endOfMonth = cal.date(byAdding: .month, value: 1, to: startOfToday)!

        if event.startsAt < startOfToday { return .past }
        if event.startsAt < startOfNextWeek { return .thisWeek }
        if event.startsAt < startOfWeekAfterNext { return .nextWeek }
        if event.startsAt < endOfMonth { return .thisMonth }
        return .later
    }

    private var groupedEvents: [(DateGroup, [Event])] {
        let groups = Dictionary(grouping: events, by: { dateGroup(for: $0) })
        let order: [DateGroup] = mode == .past
            ? [.past]
            : [.thisWeek, .nextWeek, .thisMonth, .later]
        return order.compactMap { g in
            guard let items = groups[g], !items.isEmpty else { return nil }
            return (g, items)
        }
    }

    private var list: some View {
        List {
            ForEach(groupedEvents, id: \.0) { group, items in
                Section {
                    ForEach(items) { event in
                        NavigationLink(destination: EventDetailView(event: event)) {
                            EventRow(event: event)
                        }
                        .listRowBackground(Color.white)
                        .listRowSeparatorTint(Color.tgsBorder)
                    }
                } header: {
                    Text(group.rawValue)
                        .font(TGSFont.caption)
                        .foregroundStyle(Color.tgsMuted)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.tgsCream)
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
        HStack(spacing: 14) {
            // Date badge
            VStack(spacing: 1) {
                Text(monthAbbr)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.tgsRed)
                Text(dayNum)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.tgsCharcoal)
            }
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: TGSRadius.field, style: .continuous)
                    .fill(Color.tgsRed.opacity(0.09))
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(TGSFont.rowTitle)
                    .foregroundStyle(Color.tgsCharcoal)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Label(timeStr, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(Color.tgsMuted)
                    if let venue = event.venue {
                        Text("·")
                            .foregroundStyle(Color.tgsBorder)
                        Text(venue)
                            .font(.caption)
                            .foregroundStyle(Color.tgsMuted)
                            .lineLimit(1)
                    }
                }

                Text(kantonDisplayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.tgsRed)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.tgsRed.opacity(0.10)))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    // QW-3: show full canton name, fall back to code if not found
    private var kantonDisplayName: String {
        Kanton.all.first(where: { $0.code == event.kanton })?.nameTR ?? event.kanton
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
            VStack(alignment: .leading, spacing: 16) {
                if let urlString = event.imageURL, let url = URL(string: urlString) {
                    // GeometryReader bounds the image to actual parent width so
                    // .scaledToFill() can't push the whole detail page off-screen
                    // (same fix pattern as DirectoryDetailView hero — wide banner
                    // images would otherwise force horizontal overflow).
                    GeometryReader { proxy in
                        CachedAsyncImage(url: url) { phase in
                            switch phase {
                            case .empty: Color.tgsSurface
                            case .success(let img):
                                img.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                                    .clipped()
                            case .failure: Color.tgsSurface
                            @unknown default: Color.tgsSurface
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Text(event.title)
                    .font(.title2.bold())
                    .foregroundStyle(Color.tgsCharcoal)
                    .fixedSize(horizontal: false, vertical: true)

                Text(formatted(event.startsAt))
                    .font(.subheadline)
                    .foregroundStyle(Color.tgsMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if let venue = event.venue {
                    Button {
                        openInMaps(query: [venue, event.address].compactMap { $0 }.joined(separator: ", "))
                    } label: {
                        Label(venue, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(Color.tgsCharcoal)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Haritada aç")
                }
                if let address = event.address {
                    Button {
                        openInMaps(query: address)
                    } label: {
                        Label(address, systemImage: "map")
                            .font(.subheadline)
                            .foregroundStyle(Color.tgsCharcoal)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Haritada aç")
                }

                Button {
                    Task { await scheduleReminder() }
                } label: {
                    Label("Hatırlatma kur", systemImage: "bell")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)

                if let reminderResult {
                    Text(reminderResult)
                        .font(.caption)
                        .foregroundStyle(Color.tgsMuted)
                }

                if let description = event.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Açıklama")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.tgsMuted)
                            .textCase(.uppercase)
                            .tracking(0.4)
                        Text(description)
                            .foregroundStyle(Color.tgsCharcoal)
                            .lineSpacing(4)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(TGSSpacing.lg)
        }
        .background(Color.tgsCream)
        // Floating tab bar clearance — NavigationStack push doesn't inherit
        // the parent tab's safeAreaInset.
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 80)
        }
        .navigationTitle("Etkinlik")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText, subject: Text(event.title)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Etkinliği paylaş")
            }
        }
        .task {
            // PRD §5.9: contextual push permission ask — first time the user
            // views an event detail. Idempotent on subsequent visits.
            await push.requestAuthorizationIfNeeded()
        }
    }

    /// Multi-line shareable summary. Recipients see the title in the subject
    /// (in apps that show subjects, like Mail/Slack), and the formatted
    /// title + date + venue + description + canonical URL in the body.
    private var shareText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_CH")
        f.dateStyle = .full
        f.timeStyle = .short
        var lines: [String] = ["📅 \(event.title)"]
        lines.append(f.string(from: event.startsAt))
        if let venue = event.venue, !venue.isEmpty {
            lines.append("📍 \(venue)")
        }
        if let address = event.address, !address.isEmpty {
            lines.append(address)
        }
        if let description = event.description, !description.isEmpty {
            lines.append("")
            lines.append(description)
        }
        lines.append("")
        lines.append("https://tgs-itt.ch/event/\(event.id.uuidString)")
        return lines.joined(separator: "\n")
    }

    private func formatted(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_CH")
        f.dateStyle = .full
        f.timeStyle = .short
        return f.string(from: d)
    }

    /// Open the event venue/address in Apple Maps. Mirrors the pattern used
    /// in DirectoryDetailView.openInMaps() — geocode first for a precise pin,
    /// fall back to a query URL if geocoding fails.
    private func openInMaps(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://maps.apple.com/?q=\(encoded)") {
            UIApplication.shared.open(url)
        }
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
        .tint(Color.tgsRed)
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
