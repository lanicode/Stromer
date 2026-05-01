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
