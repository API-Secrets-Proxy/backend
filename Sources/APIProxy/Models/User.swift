import Fluent
import struct Foundation.UUID

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class User: Model, @unchecked Sendable {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String
    
    @Children(for: \.$user)
    var projects: [Project]
    
    @Children(for: \.$user)
    var deviceCheckKeys: [DeviceCheckKey]

    init() { }

    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
    
    func toDTO(on db: any Database) async throws -> UserDTO {
        try await $projects.load(on: db)
        let projects = try await $projects.get(on: db)
        let projectsDTOs = try await projects.asyncMap({ try await $0.toDTO(on: db) })
        
        return .init(
            id: self.id,
            name: self.name,
            projects: projectsDTOs
        )
    }
}

extension Sequence {
    func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }
}
