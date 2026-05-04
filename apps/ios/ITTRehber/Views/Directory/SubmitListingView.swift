import PhotosUI
import SwiftUI

struct SubmitListingView: View {
    let directory: Directory
    let onSubmitted: () -> Void

    @State private var name: String = ""
    @State private var contactPerson: String = ""
    @State private var category: String = ""
    @State private var address: String = ""
    @State private var phone: String = ""
    @State private var phonePublic: Bool = true
    @State private var email: String = ""
    @State private var emailPublic: Bool = true
    @State private var website: String = ""
    @State private var description: String = ""
    @State private var selectedKantons: Set<String> = []
    @State private var selectedDirectories: Set<String>
    @State private var package: ListingPackage = .months_6
    @State private var photoItem: PhotosPickerItem?
    @State private var photoPreview: UIImage?
    @State private var imageURL: String?
    @State private var uploadingImage: Bool = false
    @State private var error: String?
    @State private var busy: Bool = false
    @State private var submitted: Listing?

    init(directory: Directory, onSubmitted: @escaping () -> Void) {
        self.directory = directory
        self.onSubmitted = onSubmitted
        self._selectedDirectories = State(initialValue: [directory.rawValue])
    }

    var body: some View {
        Form {
            Section(directory.titleTR) {
                TextField("İşletme/uzman adı", text: $name)
                TextField("İletişim kişisi (opsiyonel)", text: $contactPerson)
                TextField("Kategori (örn. Aile Hekimi)", text: $category)
            }

            Section("Bölge") {
                NavigationLink {
                    KantonMultiSelect(selected: $selectedKantons)
                } label: {
                    HStack {
                        Text("Kantonlar")
                        Spacer()
                        Text(selectedKantons.isEmpty ? "Seçiniz" : selectedKantons.sorted().joined(separator: ", "))
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink {
                    DirectoryMultiSelect(selected: $selectedDirectories, primary: directory)
                } label: {
                    HStack {
                        Text("Diğer rehberler")
                        Spacer()
                        Text(selectedDirectories.count > 1 ? "\(selectedDirectories.count - 1) ek" : "Yalnızca \(directory.titleTR)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("İletişim") {
                TextField("Adres", text: $address)
                TextField("Telefon", text: $phone)
                    .keyboardType(.phonePad)
                Toggle("Telefon herkese açık", isOn: $phonePublic)
                TextField("E-posta", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Toggle("E-posta herkese açık", isOn: $emailPublic)
                TextField("Web sitesi (https://…)", text: $website)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                TextField("Açıklama (en fazla 500 karakter)", text: $description, axis: .vertical)
                    .lineLimit(3...8)
            } footer: {
                Text("\(description.count)/500")
            }

            Section("Logo / Görsel") {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack {
                        if let img = photoPreview {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "photo")
                                .frame(width: 60, height: 60)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
                        }
                        VStack(alignment: .leading) {
                            Text(photoPreview == nil ? "Görsel seç" : "Değiştir")
                            if uploadingImage {
                                Text("Yükleniyor…").font(.caption).foregroundStyle(.secondary)
                            } else if imageURL != nil {
                                Text("Yüklendi").font(.caption).foregroundStyle(.green)
                            }
                        }
                        Spacer()
                    }
                }
                .onChange(of: photoItem) { _, newValue in
                    Task { await loadAndUploadImage(newValue) }
                }
            } footer: {
                Text("Logo zorunludur. JPG/PNG, en az 200×200, en fazla 5 MB.")
            }

            Section("Paket") {
                ForEach(ListingPackage.allCases) { pkg in
                    HStack {
                        Image(systemName: package == pkg ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(package == pkg ? Color.accentColor : Color.secondary)
                        Text(pkg.titleTR)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { package = pkg }
                }
            } footer: {
                Text("İlk ay tüm paketler için ücretsiz. Faturanız e-postanıza gönderilir; TWINT veya banka havalesi ile ödeyebilirsiniz. Uygulamada ödeme alınmaz.")
            }

            if let error {
                Section { Text(error).foregroundStyle(.red) }
            }

            Section {
                Button(action: submit) {
                    if busy { ProgressView() } else {
                        Text("İncelemeye gönder").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || busy)
            }
        }
        .navigationTitle("Hizmetinizi Ekleyin")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $submitted) { listing in
            NavigationStack {
                PostSubmitView(listing: listing, package: package, onClose: { onSubmitted() })
            }
        }
    }

    private var isValid: Bool {
        !name.isEmpty
            && !selectedKantons.isEmpty
            && !selectedDirectories.isEmpty
            && imageURL != nil
            && description.count <= 500
    }

    private func loadAndUploadImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        uploadingImage = true
        defer { uploadingImage = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            if let img = UIImage(data: data) {
                photoPreview = img
            }
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
                    if directory == primary { return }  // primary is locked
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
