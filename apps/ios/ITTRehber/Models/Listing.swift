import Foundation

struct Listing: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let directories: [String]
    let kantons: [String]
    let category: String?
    let subCategory: String?
    let address: String?
    let phone: String?
    let email: String?
    let website: String?
    let description: String?
    let imageURL: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case directories
        case kantons
        case category
        case subCategory = "sub_category"
        case address
        case phone
        case email
        case website
        case description
        case imageURL = "image_url"
        case updatedAt = "updated_at"
    }
}

struct ListingPage: Codable {
    let items: [Listing]
    let total: Int
    let page: Int
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case items
        case total
        case page
        case pageSize = "page_size"
    }
}

struct ListingSubmitInput: Codable {
    var name: String
    var contactPerson: String?
    var directories: [String]
    var kantons: [String]
    var category: String?
    var address: String?
    var phone: String?
    var phonePublic: Bool
    var email: String?
    var emailPublic: Bool
    var website: String?
    var description: String?
    var imageURL: String?
    var package: ListingPackage?

    enum CodingKeys: String, CodingKey {
        case name
        case contactPerson = "contact_person"
        case directories
        case kantons
        case category
        case address
        case phone
        case phonePublic = "phone_public"
        case email
        case emailPublic = "email_public"
        case website
        case description
        case imageURL = "image_url"
        case package
    }
}

enum ListingPackage: String, Codable, CaseIterable, Identifiable {
    case months_3
    case months_6
    case months_12

    var id: String { rawValue }

    var titleTR: String {
        switch self {
        case .months_3: return "3 ay — 60 CHF"
        case .months_6: return "6 ay — 100 CHF"
        case .months_12: return "12 ay — 180 CHF"
        }
    }

    var amountCHF: Int {
        switch self {
        case .months_3: return 60
        case .months_6: return 100
        case .months_12: return 180
        }
    }
}

struct InvoiceSummary: Codable, Identifiable {
    let id: UUID
    let listingId: UUID
    let invoiceNumber: String
    let amountChf: Int  // cents
    let package: String
    let issuedAt: Date
    let dueAt: Date?
    let paidAt: Date?
    let pdfURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case invoiceNumber = "invoice_number"
        case amountChf = "amount_chf"
        case package
        case issuedAt = "issued_at"
        case dueAt = "due_at"
        case paidAt = "paid_at"
        case pdfURL = "pdf_url"
    }
}
