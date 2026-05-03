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
    @State private var error: String?
    @State private var busy: Bool = false
    @State private var showSuccess: Bool = false

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

            Section {
                Text("İlanlar yayınlanmadan önce yönetici onayından geçer. Onay süresi: 24 saat içinde.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let error {
                Section {
                    Text(error).foregroundStyle(.red)
                }
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
        .alert("Gönderildi", isPresented: $showSuccess) {
            Button("Tamam") { onSubmitted() }
        } message: {
            Text("İlanınız incelemeye alındı. Onaylandığında bildirim alacaksınız.")
        }
    }

    private var isValid: Bool {
        !name.isEmpty && !selectedKantons.isEmpty && description.count <= 500
    }

    private func submit() {
        Task {
            busy = true
            error = nil
            defer { busy = false }
            let payload = ListingSubmitInput(
                name: name,
                contactPerson: contactPerson.isEmpty ? nil : contactPerson,
                directories: [directory.rawValue],
                kantons: Array(selectedKantons),
                category: category.isEmpty ? nil : category,
                address: address.isEmpty ? nil : address,
                phone: phone.isEmpty ? nil : phone,
                phonePublic: phonePublic,
                email: email.isEmpty ? nil : email,
                emailPublic: emailPublic,
                website: website.isEmpty ? nil : website,
                description: description.isEmpty ? nil : description,
                imageURL: nil
            )
            do {
                _ = try await APIClient.shared.submitListing(payload)
                showSuccess = true
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
