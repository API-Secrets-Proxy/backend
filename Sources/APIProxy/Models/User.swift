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

    init() { }

    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
    
    func toDTO() -> UserDTO {
        .init(
            id: self.id,
            name: self.name
        )
    }
}
