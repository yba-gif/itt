import Foundation

struct Kanton: Codable, Identifiable, Hashable {
    let code: String
    let nameTR: String
    let nameDE: String

    var id: String { code }

    enum CodingKeys: String, CodingKey {
        case code
        case nameTR = "name_tr"
        case nameDE = "name_de"
    }
}

extension Kanton {
    /// Built-in fallback used before the backend reference data has loaded
    /// (and as the offline source for the kanton picker).
    static let all: [Kanton] = [
        Kanton(code: "AG", nameTR: "Aargau", nameDE: "Aargau"),
        Kanton(code: "AI", nameTR: "Appenzell İçi", nameDE: "Appenzell Innerrhoden"),
        Kanton(code: "AR", nameTR: "Appenzell Dışı", nameDE: "Appenzell Ausserrhoden"),
        Kanton(code: "BE", nameTR: "Bern", nameDE: "Bern"),
        Kanton(code: "BL", nameTR: "Basel-Land", nameDE: "Basel-Landschaft"),
        Kanton(code: "BS", nameTR: "Basel-Şehir", nameDE: "Basel-Stadt"),
        Kanton(code: "FR", nameTR: "Fribourg", nameDE: "Freiburg"),
        Kanton(code: "GE", nameTR: "Cenevre", nameDE: "Genf"),
        Kanton(code: "GL", nameTR: "Glarus", nameDE: "Glarus"),
        Kanton(code: "GR", nameTR: "Graubünden", nameDE: "Graubünden"),
        Kanton(code: "JU", nameTR: "Jura", nameDE: "Jura"),
        Kanton(code: "LU", nameTR: "Luzern", nameDE: "Luzern"),
        Kanton(code: "NE", nameTR: "Neuchâtel", nameDE: "Neuenburg"),
        Kanton(code: "NW", nameTR: "Nidwalden", nameDE: "Nidwalden"),
        Kanton(code: "OW", nameTR: "Obwalden", nameDE: "Obwalden"),
        Kanton(code: "SG", nameTR: "St. Gallen", nameDE: "St. Gallen"),
        Kanton(code: "SH", nameTR: "Schaffhausen", nameDE: "Schaffhausen"),
        Kanton(code: "SO", nameTR: "Solothurn", nameDE: "Solothurn"),
        Kanton(code: "SZ", nameTR: "Schwyz", nameDE: "Schwyz"),
        Kanton(code: "TG", nameTR: "Thurgau", nameDE: "Thurgau"),
        Kanton(code: "TI", nameTR: "Ticino", nameDE: "Tessin"),
        Kanton(code: "UR", nameTR: "Uri", nameDE: "Uri"),
        Kanton(code: "VD", nameTR: "Vaud", nameDE: "Waadt"),
        Kanton(code: "VS", nameTR: "Valais", nameDE: "Wallis"),
        Kanton(code: "ZG", nameTR: "Zug", nameDE: "Zug"),
        Kanton(code: "ZH", nameTR: "Zürih", nameDE: "Zürich"),
    ]
}
