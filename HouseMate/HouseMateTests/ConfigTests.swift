import XCTest
@testable import HouseMate

final class ConfigTests: XCTestCase {
    func test_supabaseClient_isNotNil() {
        XCTAssertNotNil(supabase)
    }
}
