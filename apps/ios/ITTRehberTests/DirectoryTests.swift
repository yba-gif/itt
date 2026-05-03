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

    func testOnlySaglikIsPhase1Active() {
        XCTAssertTrue(Directory.saglik.isPhase1Active)
        for d in Directory.allCases where d != .saglik {
            XCTAssertFalse(d.isPhase1Active, "\(d.rawValue) should not be Phase 1 active")
        }
    }

    func testKantonsCount() {
        XCTAssertEqual(Kanton.all.count, 26)
    }
}
