import PhotosUI
import SwiftUI

// MARK: - Multi-step Submit (P2-4)

struct SubmitListingView: View {
    let directory: Directory
    let onSubmitted: () -> Void

    @State private var step: Int = 0
    // Step 1 — Basics
    @State private var name: String = ""
    @State private var contactPerson: String = ""
    @State private var category: String = ""
    @State private var selectedKantons: Set<String> = []
    @State private var selectedDirectories: Set<String>
    // Step 2 — Contact
    @State private var address: String = ""
    @State private var phone: String = ""
    @State private var phonePublic: Bool = true
    @State private var email: String = ""
    @State private var emailPublic: Bool = true
    @State private var website: String = ""
    @State private var description: String = ""
    // Step 3 — Photo + Package
    @State private var package: ListingPackage = .months_6
    @State private var photoItem: PhotosPickerItem?
    @State private var photoPreview: UIImage?
    @State private var imageURL: String?
    @State private var uploadingImage: Bool = false
    // Submission
    @State private var error: String?
    @State private var busy: Bool = false
    @State private var submitted: Listing?

    private static let totalSteps = 3

    init(directory: Directory, onSubmitted: @escaping () -> Void) {
        self.directory = directory
        self.onSubmitted = onSubmitted
        self._selectedDirectories = State(initialValue: [directory.rawValue])
    }

    var body: some View {
        VStack(spacing: 0) {
            // P2-4: step progress indicator
            StepProgressBar(currentStep: step, totalSteps: Self.totalSteps)
                .padding(.horizontal, TGSSpacing.xl)
                .padding(.top, TGSSpacing.lg)
                .padding(.bottom, TGSSpacing.md)

            ScrollView {
                VStack(spacing: TGSSpacing.lg) {
                    switch step {
                    case 0: step1
                    case 1: step2
                    default: step3
                    }
                }
                .padding(.horizontal, TGSSpacing.lg)
                .padding(.bottom, TGSSpacing.xxl)
                .animation(.easeInOut(duration: 0.22), value: step)
            }
            .background(Color.tgsCream)

            // Navigation buttons
            navigationBar
        }
        .background(Color.tgsCream)
        .navigationTitle("Hizmetinizi Ekleyin")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color.tgsRed)
        .sheet(item: $submitted) { listing in
            NavigationStack {
                PostSubmitView(listing: listing, package: package, onClose: { onSubmitted() })
            }
        }
    }

    // MARK: Step 1 — Basics

    private var step1: some View {
        VStack(spacing: TGSSpacing.lg) {
            stepHeader(icon: "building.2.fill", title: "Temel Bilgiler", step: 1)

            TGSFormSection(header: directory.titleTR) {
                TGSFieldRow(icon: "person.text.rectangle",
                            placeholder: "İşletme/uzman adı *",
                            text: $name)
                TGSFieldRow(icon: "person",
                            placeholder: "İletişim kişisi (opsiyonel)",
                            text: $contactPerson)
                TGSFieldRow(icon: "tag",
                            placeholder: "Kategori (örn. Aile Hekimi)",
                            text: $category,
                            showDivider: false)
            }

            TGSFormSection(header: "Bölge") {
                NavigationLink {
                    KantonMultiSelect(selected: $selectedKantons)
                } label: {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.tgsMuted)
                            .frame(width: 20)
                        Text("Kantonlar *")
                            .font(TGSFont.body)
                            .foregroundStyle(selectedKantons.isEmpty ? Color.tgsMuted : Color.tgsCharcoal)
                        Spacer()
                        if !selectedKantons.isEmpty {
                            Text(selectedKantons.sorted().prefix(3).joined(separator: ", "))
                                .font(TGSFont.micro)
                                .foregroundStyle(Color.tgsMuted)
                                .lineLimit(1)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.tgsMuted)
                    }
                    .padding(.horizontal, TGSSpacing.lg)
                    .padding(.vertical, TGSSpacing.md)
                }
                Divider().overlay(Color.tgsBorder).padding(.leading, TGSSpacing.lg + 20 + TGSSpacing.md)

                NavigationLink {
                    DirectoryMultiSelect(selected: $selectedDirectories, primary: directory)
                } label: {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.tgsMuted)
                            .frame(width: 20)
                        Text("Diğer rehberler")
                            .font(TGSFont.body)
                            .foregroundStyle(Color.tgsCharcoal)
                        Spacer()
                        Text(selectedDirectories.count > 1 ? "\(selectedDirectories.count - 1) ek" : "Yalnızca \(directory.titleTR)")
                            .font(TGSFont.micro)
                            .foregroundStyle(Color.tgsMuted)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.tgsMuted)
                    }
                    .padding(.horizontal, TGSSpacing.lg)
                    .padding(.vertical, TGSSpacing.md)
                }
            }
        }
    }

    // MARK: Step 2 — Contact

    private var step2: some View {
        VStack(spacing: TGSSpacing.lg) {
            stepHeader(icon: "envelope.fill", title: "İletişim Bilgileri", step: 2)

            TGSFormSection(header: "Adres ve İletişim") {
                TGSFieldRow(icon: "mappin.and.ellipse", placeholder: "Adres", text: $address)
                TGSFieldRow(icon: "phone", placeholder: "Telefon",
                            text: $phone, keyboardType: .phonePad)
                toggleRow(label: "Telefon herkese açık", isOn: $phonePublic)
                TGSFieldRow(icon: "envelope", placeholder: "E-posta",
                            text: $email, keyboardType: .emailAddress,
                            autocapitalization: .never, autocorrect: false)
                toggleRow(label: "E-posta herkese açık", isOn: $emailPublic)
                TGSFieldRow(icon: "globe", placeholder: "Web sitesi (https://…)",
                            text: $website, autocapitalization: .never,
                            autocorrect: false, showDivider: false)
            }

            TGSFormSection(
                header: "Açıklama",
                footer: "\(description.count)/500 karakter"
            ) {
                TextField("Kendinizi tanıtın…", text: $description, axis: .vertical)
                    .lineLimit(4...8)
                    .font(TGSFont.body)
                    .foregroundStyle(Color.tgsCharcoal)
                    .padding(.horizontal, TGSSpacing.lg)
                    .padding(.vertical, TGSSpacing.md)
            }
        }
    }

    // MARK: Step 3 — Photo + Package

    private var step3: some View {
        VStack(spacing: TGSSpacing.lg) {
            stepHeader(icon: "photo.badge.plus", title: "Logo ve Paket", step: 3)

            TGSFormSection(
                header: "Logo / Görsel",
                footer: "Logo zorunludur. JPG/PNG, en az 200×200, en fazla 5 MB."
            ) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack(spacing: TGSSpacing.md) {
                        if let img = photoPreview {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: TGSRadius.field))
                        } else {
                            RoundedRectangle(cornerRadius: TGSRadius.field)
                                .fill(Color.tgsSurface)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color.tgsMuted)
                                )
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(photoPreview == nil ? "Görsel seç" : "Değiştir")
                                .font(TGSFont.body)
                                .foregroundStyle(Color.tgsCharcoal)
                            if uploadingImage {
                                Text("Yükleniyor…").font(TGSFont.micro).foregroundStyle(Color.tgsMuted)
                            } else if imageURL != nil {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.tgsSuccess)
                                    Text("Yüklendi")
                                }
                                .font(TGSFont.micro)
                                .foregroundStyle(Color.tgsSuccess)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, TGSSpacing.lg)
                    .padding(.vertical, TGSSpacing.md)
                }
                .onChange(of: photoItem) { newValue in
                    Task { await loadAndUploadImage(newValue) }
                }
            }

            TGSFormSection(
                header: "Paket",
                footer: "İlk ay tüm paketler için ücretsiz. Faturanız e-postanıza gönderilir; TWINT veya banka havalesi ile ödeyebilirsiniz. Uygulamada ödeme alınmaz."
            ) {
                ForEach(Array(ListingPackage.allCases.enumerated()), id: \.element.id) { idx, pkg in
                    VStack(spacing: 0) {
                        HStack(spacing: TGSSpacing.md) {
                            Image(systemName: package == pkg ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(package == pkg ? Color.tgsRed : Color.tgsMuted)
                                .font(.system(size: 18))
                            Text(pkg.titleTR)
                                .font(TGSFont.body)
                                .foregroundStyle(Color.tgsCharcoal)
                            Spacer()
                        }
                        .padding(.horizontal, TGSSpacing.lg)
                        .padding(.vertical, TGSSpacing.md)
                        .contentShape(Rectangle())
                        .onTapGesture { package = pkg }

                        if idx < ListingPackage.allCases.count - 1 {
                            Divider().overlay(Color.tgsBorder).padding(.leading, TGSSpacing.lg + 18 + TGSSpacing.md)
                        }
                    }
                }
            }

            // Inline error
            if let error {
                HStack(spacing: TGSSpacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.tgsError)
                    Text(error)
                        .font(TGSFont.subheadline)
                        .foregroundStyle(Color.tgsError)
                    Spacer()
                }
                .padding(TGSSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: TGSRadius.field, style: .continuous)
                        .fill(Color.tgsErrorBg)
                )
                .transition(.opacity)
            }

            // Validation hints (P0-3)
            if !validationHints.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Göndermeden önce:")
                        .font(TGSFont.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.tgsRed)
                    ForEach(validationHints, id: \.self) { hint in
                        Label(hint, systemImage: "exclamationmark.circle.fill")
                            .font(TGSFont.micro)
                            .foregroundStyle(Color.tgsRed)
                    }
                }
                .padding(TGSSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: TGSRadius.field, style: .continuous)
                        .fill(Color.tgsRed.opacity(0.06))
                )
            }
        }
    }

    // MARK: Navigation bar

    private var navigationBar: some View {
        HStack(spacing: TGSSpacing.md) {
            if step > 0 {
                Button("Geri") {
                    withAnimation(.easeInOut(duration: 0.22)) { step -= 1 }
                }
                .buttonStyle(.bordered)
                .tint(Color.tgsMuted)
                .accessibilityLabel("Önceki adıma dön")
            }

            Spacer()

            if step < Self.totalSteps - 1 {
                Button("İleri") {
                    withAnimation(.easeInOut(duration: 0.22)) { step += 1 }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.tgsRed)
                .disabled(!canAdvance)
                .accessibilityLabel("Sonraki adıma geç")
                .accessibilityHint(canAdvance ? "" : "Bu adımdaki zorunlu alanları doldurun")
            } else {
                Button(action: submit) {
                    if busy { ProgressView().tint(.white) } else {
                        Text("İncelemeye gönder")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.tgsRed)
                .disabled(!isValid || busy)
            }
        }
        .padding(.horizontal, TGSSpacing.lg)
        .padding(.vertical, TGSSpacing.md)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: Helpers

    @ViewBuilder
    private func stepHeader(icon: String, title: String, step: Int) -> some View {
        HStack(spacing: TGSSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.tgsRed.opacity(0.10))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.tgsRed)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Adım \(step) / \(Self.totalSteps)")
                    .font(TGSFont.micro)
                    .foregroundStyle(Color.tgsMuted)
                Text(title)
                    .font(TGSFont.headline)
                    .foregroundStyle(Color.tgsCharcoal)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Adım \(step) / \(Self.totalSteps): \(title)")
    }

    @ViewBuilder
    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(TGSFont.body)
                .foregroundStyle(Color.tgsCharcoal)
        }
        .padding(.horizontal, TGSSpacing.lg)
        .padding(.vertical, TGSSpacing.xs + 2)
        Divider().overlay(Color.tgsBorder).padding(.leading, TGSSpacing.lg)
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return !name.isEmpty && !selectedKantons.isEmpty
        case 1: return true // contact step is all optional
        default: return true
        }
    }

    private var isValid: Bool {
        !name.isEmpty
            && !selectedKantons.isEmpty
            && !selectedDirectories.isEmpty
            && imageURL != nil
            && description.count <= 500
    }

    private var validationHints: [String] {
        var hints: [String] = []
        if name.isEmpty            { hints.append("İşletme/uzman adı girin") }
        if selectedKantons.isEmpty { hints.append("En az bir kanton seçin") }
        if imageURL == nil && !uploadingImage { hints.append("Logo görseli yükleyin") }
        if description.count > 500 { hints.append("Açıklama \(description.count - 500) karakter fazla") }
        return hints
    }

    private func loadAndUploadImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        uploadingImage = true
        defer { uploadingImage = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            if let img = UIImage(data: data) { photoPreview = img }
            let url = try await APIClient.shared.uploadImage(
                data: data, filename: "logo.jpg", mime: "image/jpeg"
            )
            imageURL = url
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func submit() {
        Task {
            busy = true
            error = nil
            defer { busy = false }
            let payload = ListingSubmitInput(
                name: name,
                contactPerson: contactPerson.isEmpty ? nil : contactPerson,
                directories: Array(selectedDirectories),
                kantons: Array(selectedKantons),
                category: category.isEmpty ? nil : category,
                address: address.isEmpty ? nil : address,
                phone: phone.isEmpty ? nil : phone,
                phonePublic: phonePublic,
                email: email.isEmpty ? nil : email,
                emailPublic: emailPublic,
                website: website.isEmpty ? nil : website,
                description: description.isEmpty ? nil : description,
                imageURL: imageURL,
                package: package
            )
            do {
                let listing = try await APIClient.shared.submitListing(payload)
                submitted = listing
            } catch {
                self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

// MARK: - Step Progress Bar

struct StepProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: TGSSpacing.sm) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= currentStep ? Color.tgsRed : Color.tgsBorder)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.25), value: currentStep)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Adım \(currentStep + 1) / \(totalSteps)")
        .accessibilityValue("\(Int((Double(currentStep + 1) / Double(totalSteps)) * 100)) yüzde")
    }
}

// MARK: - Supporting views (unchanged from original)

struct KantonMultiSelect: View {
    @Binding var selected: Set<String>

    var body: some View {
        List {
            ForEach(Kanton.all) { kanton in
                Button {
                    if selected.contains(kanton.code) {
                        selected.remove(kanton.code)
                    } else {
                        selected.insert(kanton.code)
                    }
                } label: {
                    HStack {
                        Text("\(kanton.code) — \(kanton.nameTR)")
                        Spacer()
                        if selected.contains(kanton.code) {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Kantonlar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DirectoryMultiSelect: View {
    @Binding var selected: Set<String>
    let primary: Directory

    var body: some View {
        List {
            ForEach(Directory.allCases) { directory in
                Button {
                    if directory == primary { return }
                    if selected.contains(directory.rawValue) {
                        selected.remove(directory.rawValue)
                    } else {
                        selected.insert(directory.rawValue)
                    }
                } label: {
                    HStack {
                        Image(systemName: directory.systemImage)
                            .foregroundStyle(directory == primary ? Color.accentColor : .secondary)
                        Text(directory.titleTR)
                        if directory == primary {
                            Text("(birincil)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selected.contains(directory.rawValue) {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Rehberler")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PostSubmitView: View {
    let listing: Listing
    let package: ListingPackage
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                    VStack(alignment: .leading) {
                        Text("Başvurunuz alındı")
                            .font(.title2.bold())
                        Text("Yönetici incelemesinden sonra yayında olacaktır.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)

                Divider()

                Group {
                    Label("Faturanız e-postanıza gönderildi", systemImage: "envelope.fill")
                        .font(.headline)
                    Text("İlk ay ücretsizdir. İkinci ay başlamadan önce ödemenizin alınması gerekir.")
                        .font(.subheadline)
                }

                Group {
                    Label("Ödeme yöntemleri", systemImage: "francsign.circle")
                        .font(.headline)
                    Text("• TWINT — fatura QR kodunu tarayın\n• Banka havalesi — IBAN ve referans numarası faturada\n\nUygulamada ödeme alınmaz (App Store kuralları gereği).")
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Paket", systemImage: "calendar.badge.clock")
                        .font(.headline)
                    Text(package.titleTR).font(.subheadline)
                }

                Spacer().frame(height: 16)
                Button {
                    onClose()
                } label: {
                    Text("Tamam").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .navigationTitle("Tamamlandı")
        .navigationBarTitleDisplayMode(.inline)
    }
}
