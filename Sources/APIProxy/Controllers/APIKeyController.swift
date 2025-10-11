import Fluent
import Vapor

struct APIKeyController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let keys = routes.grouped("users", ":userID", "projects", ":projectID", "keys")

        keys.get(use: self.index)
        keys.post(use: self.create)
        keys.group(":keyID") { key in
            key.get(use: self.get)
            key.delete(use: self.delete)
        }
    }

    @Sendable
    func index(req: Request) async throws -> [APIKeySendingDTO] {
        guard let project = try await Project.find(req.parameters.require("projectID"), on: req.db) else {
            throw Abort(.unauthorized)
        }
        try await project.$user.load(on: req.db)
        let user = try await project.$user.get(on: req.db)
        guard try user.requireID() == req.parameters.get("useerID") else {
            throw Abort(.unauthorized)
        }
        
        return try await APIKey.query(on: req.db).filter(\.$project.$id == project.requireID()).all().map { $0.toDTO() }
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
        
        let key = APIKey(name: name, description: keyDTO.description ?? "", partialKey: dbKey)
        
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
    func get(req: Request) async throws -> APIKeySendingDTO {
        guard let key = try await APIKey.find(req.parameters.get("keyID"), on: req.db) else {
            throw Abort(.notFound)
        }

        return key.toDTO()
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let key = try await APIKey.find(req.parameters.get("keyID"), on: req.db) else {
            throw Abort(.notFound)
        }

        try await key.delete(on: req.db)
        return .accepted
    }
}
