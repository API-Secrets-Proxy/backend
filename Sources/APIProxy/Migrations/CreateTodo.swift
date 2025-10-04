import Fluent

extension User: Migratable {
    static let migrations: [any Migration] = [
        CreateUserMigration(),
    ]
    
    struct CreateUserMigration: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema(User.schema)
                .id()
                .field("name", .string, .required)
                .create()
        }

        func revert(on database: any Database) async throws {
            try await database.schema(User.schema).delete()
        }
    }
}
