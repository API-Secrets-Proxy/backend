import Fluent
import Vapor

struct APIKeyController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let keys = routes.grouped("keys")

        keys.get(use: self.index)
        keys.post(use: self.create)
        keys.group(":keyID") { key in
            key.delete(use: self.delete)
        }
    }

    @Sendable
    func index(req: Request) async throws -> [UserDTO] {
        try await User.query(on: req.db).all().map { $0.toDTO() }
    }

    @Sendable
    func create(req: Request) async throws -> UserDTO {
        let key = try req.content.decode(UserDTO.self).toModel()

        try await key.save(on: req.db)
        return key.toDTO()
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let key = try await APIKey.find(req.parameters.get("keyID"), on: req.db) else {
            throw Abort(.notFound)
        }

        try await key.delete(on: req.db)
        return .noContent
    }
}
