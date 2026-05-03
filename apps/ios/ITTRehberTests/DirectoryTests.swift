import XCTest
@testable import ITTRehber

final class DirectoryTests: XCTestCase {
    func testRawValuesMatchBackend() {
        // The backend `directories[]` codes must equal Directory.rawValue.
        let codes = Set(Directory.allCases.map(\.rawValue))
        let expected: Set<String> = [
            "saglik", "hukuk", "isletme", "finans", "tercume",
            "meslek", "okullar", "camiler", "mezunlar", "destek_dersi",
        ]
        XCTAssertEqual(codes, expected)
    }

    func testAllDirectoriesActiveInPhase2() {
        for d in Directory.allCases {
            XCTAssertTrue(d.isActive, "\(d.rawValue) should be active in Phase 2")
        }
    }

    func testKantonsCount() {
        XCTAssertEqual(Kanton.all.count, 26)
    }
}
