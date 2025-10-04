import Fluent
import Vapor

struct APIKeyController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let keys = routes.grouped("users", ":userID", "projects", ":projectID", "keys")

        keys.get(use: self.index)
        keys.post(use: self.create)
        keys.group(":keyID") { key in
            key.delete(use: self.delete)
        }
    }

    @Sendable
    func index(req: Request) async throws -> [APIKeySendingDTO] {
        try await APIKey.query(on: req.db).all().map { $0.toDTO() }
    }

    @Sendable
    func create(req: Request) async throws -> APIKeySendingDTO {
        let keyDTO = try req.content.decode(APIKeyRecievingDTO.self)
        
        guard let name = keyDTO.name else {
            throw Abort(.badRequest, reason: "Name not specified")
        }
        
        guard let apiKey = keyDTO.apiKey else {
            throw Abort(.badRequest, reason: "API key not included")
        }
        
        let (userKey, dbKey) = try KeySplitter.split(key: apiKey)
        
        let key = APIKey(name: name, partialKey: dbKey)
        
        guard let project = try await Project.find(req.parameters.get("projectID"), on: req.db) else {
            throw Abort(.badRequest, reason: "Project Not Found")
        }

        key.$project.id = try project.requireID()

        try await key.save(on: req.db)
        
        // Construct return dto
        var dto = key.toDTO()
        // Add key to dto just for creation
        dto.userPartialKey = userKey
        
        return dto
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
