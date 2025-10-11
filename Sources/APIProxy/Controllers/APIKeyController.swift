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

    /// GET /users/:userID/projects/:projectID/keys
    /// 
    /// Retrieves all API keys for a specific project belonging to a user.
    /// 
    /// ## Path Parameters
    /// - userID: The unique identifier of the user
    /// - projectID: The unique identifier of the project
    /// 
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID and project ID parameters
    /// - Returns: Array of ``APIKeySendingDTO`` objects containing API key information
    @Sendable
    func index(req: Request) async throws -> [APIKeySendingDTO] {
        guard let project = try await Project.find(req.parameters.require("projectID"), on: req.db) else {
            throw Abort(.unauthorized)
        }
        try await project.$user.load(on: req.db)
        let user = try await project.$user.get(on: req.db)
        guard try user.requireID() == req.parameters.get("userID") else {
            throw Abort(.unauthorized)
        }
        
        return try await APIKey.query(on: req.db).filter(\.$project.$id == project.requireID()).all().map { $0.toDTO() }
    }

    /// POST /users/:userID/projects/:projectID/keys
    /// 
    /// Creates a new API key for a specific project belonging to a user.
    /// 
    /// ## Path Parameters
    /// - userID: The unique identifier of the user
    /// - projectID: The unique identifier of the project
    /// 
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID, project ID parameters, and API key data in the request body
    /// - Returns: ``APIKeySendingDTO`` object containing the created API key information with the user's partial key
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

    /// GET /users/:userID/projects/:projectID/keys/:keyID
    /// 
    /// Retrieves a specific API key by its unique identifier.
    /// 
    /// ## Path Parameters
    /// - userID: The unique identifier of the user
    /// - projectID: The unique identifier of the project
    /// - keyID: The unique identifier of the API key
    /// 
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID, project ID, and key ID parameters
    /// - Returns: ``APIKeySendingDTO`` object containing the API key information
    @Sendable
    func get(req: Request) async throws -> APIKeySendingDTO {
        guard let key = try await APIKey.find(req.parameters.get("keyID"), on: req.db) else {
            throw Abort(.notFound)
        }

        return key.toDTO()
    }

    /// DELETE /users/:userID/projects/:projectID/keys/:keyID
    /// 
    /// Deletes a specific API key by its unique identifier.
    /// 
    /// ## Path Parameters
    /// - userID: The unique identifier of the user
    /// - projectID: The unique identifier of the project
    /// - keyID: The unique identifier of the API key
    /// 
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID, project ID, and key ID parameters
    /// - Returns: HTTP status code indicating the result of the deletion operation
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let key = try await APIKey.find(req.parameters.get("keyID"), on: req.db) else {
            throw Abort(.notFound)
        }

        try await key.delete(on: req.db)
        return .accepted
    }
}
