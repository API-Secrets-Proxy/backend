import Fluent

extension DeviceCheckKey: Migratable {
    static let migrations: [any Migration] = [
        CreateMigration(),
    ]
    
    struct CreateMigration: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema(DeviceCheckKey.schema)
                .id()
                .field("team_id", .string, .required)
                .field("secret_key", .string, .required)
                .field("key_id", .string, .required)
                .field("bypass_token", .string, .required)
                .field("user_id", .string, .required)
                .create()
        }

        func revert(on database: any Database) async throws {
            try await database.schema(DeviceCheckKey.schema).delete()
        }
    }
}
