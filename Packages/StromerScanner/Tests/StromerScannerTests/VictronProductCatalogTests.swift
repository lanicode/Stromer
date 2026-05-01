@testable import StromerScanner
import XCTest

final class VictronProductCatalogTests: XCTestCase {
    func testLookupSmartShuntFamily() {
        let entry = VictronProductCatalog.lookup(productID: 0xA389)

        XCTAssertEqual(entry?.modelName, "SmartShunt 500A/50mV")
        XCTAssertEqual(entry?.deviceType, .batteryMonitor)
        XCTAssertEqual(entry?.supportStatus, .supported)
    }

    func testLookupMPPTFamily() {
        let entry = VictronProductCatalog.lookup(productID: 0xA057)

        XCTAssertEqual(entry?.modelName, "SmartSolar MPPT 100/50")
        XCTAssertEqual(entry?.deviceType, .solarCharger)
        XCTAssertEqual(entry?.supportStatus, .supported)
    }

    func testLookupPlannedPhase37Family() {
        let entry = VictronProductCatalog.lookup(productID: 0xA3C0)

        XCTAssertEqual(entry?.deviceType, .dcDcConverter)
        XCTAssertEqual(entry?.supportStatus, .plannedPhase37)
    }

    func testLookupOrionSmart12V12V30ADCConverter() {
        assertOrionEntry(
            productID: 0xA3C8,
            modelName: "Orion Smart 12V/12V-30A DC-DC Converter"
        )
    }

    func testLookupOrionSmart24V48V85ADCConverter() {
        assertOrionEntry(
            productID: 0xA3CC,
            modelName: "Orion Smart 24V/48V-8.5A DC-DC Converter"
        )
    }

    func testLookupOrionSmart48V24V16ADCConverter() {
        assertOrionEntry(
            productID: 0xA3CE,
            modelName: "Orion Smart 48V/24V-16A DC-DC Converter"
        )
    }

    func testLookupOrionSmart12V12V30ABuckBoostConverter() {
        assertOrionEntry(
            productID: 0xA3D0,
            modelName: "Orion Smart 12V/12V-30A Buck-Boost Converter"
        )
    }

    func testLookupOrionSmart24V24V17ABuckBoostConverter() {
        assertOrionEntry(
            productID: 0xA3D3,
            modelName: "Orion Smart Orion 24V/24V-17A Buck-Boost Converter"
        )
    }

    func testLookupOutOfScopeFamily() {
        let entry = VictronProductCatalog.lookup(productID: 0xA3E5)

        XCTAssertEqual(entry?.deviceType, .lynxBMS)
        XCTAssertEqual(entry?.supportStatus, .outOfScope)
    }

    func testRecordTypeOverridesUnknownProductSupport() {
        XCTAssertEqual(
            VictronProductCatalog.supportStatus(productID: 0xFFFF, recordType: 0x01),
            .supported
        )
        XCTAssertEqual(
            VictronProductCatalog.supportStatus(productID: 0xFFFF, recordType: 0x03),
            .plannedPhase37
        )
        XCTAssertEqual(
            VictronProductCatalog.supportStatus(productID: 0xFFFF, recordType: 0x0C),
            .outOfScope
        )
    }

    func testUnknownProductFallsBackToOutOfScope() {
        XCTAssertNil(VictronProductCatalog.lookup(productID: 0xFFFF))
        XCTAssertEqual(
            VictronProductCatalog.supportStatus(productID: 0xFFFF, recordType: 0xFE),
            .outOfScope
        )
    }
}

private func assertOrionEntry(
    productID: UInt16,
    modelName: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let entry = VictronProductCatalog.lookup(productID: productID)

    XCTAssertEqual(entry?.modelName, modelName, file: file, line: line)
    XCTAssertEqual(entry?.deviceType, .dcDcConverter, file: file, line: line)
    XCTAssertEqual(entry?.supportStatus, .plannedPhase37, file: file, line: line)
}
