import Fluent
import Vapor

struct UserController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let users = routes.grouped("users")

        users.post(use: self.create)
        users.get(use: self.create)
        users.group(":userID") { user in
            user.get(use: self.get)
            user.delete(use: self.delete)
        }
    }

    /// POST /users
    /// 
    /// Creates a new user account.
    /// 
    /// ## Request Body
    /// Expects a ``UserDTO`` object containing:
    /// - name: The name of the user (optional)
    /// - projects: Array of associated projects (optional)
    /// 
    /// ```json
    /// {
    ///   "name": "John Doe",
    ///   "projects": []
    /// }
    /// ```
    /// 
    /// - Parameters:
    ///   - req: The HTTP request containing user data in the request body
    /// - Returns: ``UserDTO`` object containing the created user information
    @Sendable
    func create(req: Request) async throws -> UserDTO {
        let user = try req.auth.require(User.self)

        try await user.save(on: req.db)
        return try await user.toDTO(on: req.db)
    }
    
    /// GET /users/:userID
    /// 
    /// Retrieves a specific user by their unique identifier.
    /// 
    /// ## Path Parameters
    /// - userID: The unique identifier of the user
    /// 
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID parameter
    /// - Returns: ``UserDTO`` object containing the user information
    @Sendable
    func get(req: Request) async throws -> UserDTO {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        return try await user.toDTO(on: req.db)
    }

    /// DELETE /users/:userID
    /// 
    /// Deletes a specific user by their unique identifier.
    /// 
    /// ## Path Parameters
    /// - userID: The unique identifier of the user
    /// 
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID parameter
    /// - Returns: HTTP status code indicating the result of the deletion operation
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound)
        }

        try await user.delete(on: req.db)
        return .accepted
    }
}
