import Fluent
import struct Foundation.UUID

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class Project: Model, @unchecked Sendable {
    static let schema = "projects"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Parent(key: "user_id")
    var user: User
    
    @Children(for: \.$project)
    var apiKeys: [APIKey]
    
    init() { }

    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
    
    func toDTO(on db: any Database) async throws -> ProjectDTO {
        try await $apiKeys.load(on: db)
        let keys = try await $apiKeys.get(on: db)
        let keysDTO = keys.map({ $0.toDTO() })
        
        return .init(
            id: self.id,
            name: self.name,
            keys: keysDTO
        )
    }
}
