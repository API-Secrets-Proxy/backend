import Fluent

extension APIKey: Migratable {
    static let migrations: [any Migration] = [
        CreateMigration(),
    ]
    
    struct CreateMigration: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema(APIKey.schema)
                .id()
                .field("name", .string, .required)
                .field("partial_key", .string, .required)
                .create()
        }

        func revert(on database: any Database) async throws {
            try await database.schema(APIKey.schema).delete()
        }
    }
}
