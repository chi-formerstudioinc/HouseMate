// HouseMateTests/Config/DateDecoderTests.swift
import XCTest
@testable import HouseMate

final class DateDecoderTests: XCTestCase {
    struct DateWrapper: Decodable {
        let value: Date
    }

    func test_decodesISO8601Timestamp() throws {
        let json = #"{"value":"2026-03-12T10:00:00Z"}"#.data(using: .utf8)!
        let result = try HouseMateDecoder.decode(DateWrapper.self, from: json)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let components = utcCalendar.dateComponents([.year, .month, .day, .hour], from: result.value)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 12)
        XCTAssertEqual(components.hour, 10)
    }

    func test_decodesDateOnlyString() throws {
        let json = #"{"value":"2026-03-12"}"#.data(using: .utf8)!
        let result = try HouseMateDecoder.decode(DateWrapper.self, from: json)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let components = utcCalendar.dateComponents([.year, .month, .day], from: result.value)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 12)
    }
}
