import AppIntents
import Foundation
import StromerScanner

public struct StromerDeviceEntity: AppEntity, Identifiable {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Gerät")
    public static let defaultQuery = StromerDeviceQuery()

    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    public var uuid: UUID? {
        UUID(uuidString: id)
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

public struct StromerDeviceQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [StromerDeviceEntity] {
        let entities = loadEntities()
        return entities.filter { identifiers.contains($0.id) }
    }

    public func suggestedEntities() async throws -> [StromerDeviceEntity] {
        loadEntities()
    }

    private func loadEntities() -> [StromerDeviceEntity] {
        do {
            let provider = try StromerWidgetSnapshotProvider.appGroup()
            return try provider.deviceOptions().map {
                StromerDeviceEntity(id: $0.id.uuidString, name: $0.name)
            }
        } catch {
            return []
        }
    }
}

public struct StromerWidgetConfigurationIntent: WidgetConfigurationIntent {
    public static let title: LocalizedStringResource = "Stromer Gerät"
    public static let description = IntentDescription("Wähle ein registriertes Victron-Gerät für das Widget.")

    @Parameter(title: "Gerät")
    public var device: StromerDeviceEntity?

    public init() {}
}
