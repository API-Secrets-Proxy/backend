import Fluent
import Vapor

struct ProjectController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let projects = routes.grouped("me", "projects")

        projects.get(use: self.index)
        projects.post(use: self.create)
        projects.group(":projectID") { project in
            project.get(use: self.get)
            project.delete(use: self.delete)
        }
    }

    /// GET /me/projects
    /// 
    /// Retrieves all projects belonging to a specific user.
    /// 
    /// ## Required Headers
    /// - Expects a bearer token object from Clerk. More information here: https://clerk.com/docs/react/reference/hooks/use-auth
    ///
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID parameter
    /// - Returns: Array of ``ProjectDTO`` objects containing project information
    @Sendable
    func index(req: Request) async throws -> [ProjectDTO] {
        let user = try req.auth.require(User.self)
        
        return try await Project.query(on: req.db).filter(\.$user.$id == user.requireID()).all().asyncMap { try await $0.toDTO(on: req.db) }
    }

    /// POST /me/projects
    /// 
    /// Creates a new project for a specific user.
    /// 
    /// ## Required Headers
    /// - Expects a bearer token object from Clerk. More information here: https://clerk.com/docs/react/reference/hooks/use-auth
    ///
    /// ## Request Body
    /// Expects a ``ProjectDTO`` object containing:
    /// - name: The name of the project (optional)
    /// - description: The description of the project (required)
    /// - keys: Array of associated API keys (optional)
    /// 
    /// ```json
    /// {
    ///   "name": "My Project",
    ///   "description": "Project description",
    ///   "keys": []
    /// }
    /// ```
    /// 
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID parameter and project data in the request body
    /// - Returns: ``ProjectDTO`` object containing the created project information
    @Sendable
    func create(req: Request) async throws -> ProjectDTO {
        let project = try req.content.decode(ProjectDTO.self).toModel()
        let user = try req.auth.require(User.self)

        project.$user.id = try user.requireID()
        
        try await project.save(on: req.db)
        return try await project.toDTO(on: req.db)
    }

    /// GET /me/projects/:projectID
    /// 
    /// Retrieves a specific project by its unique identifier.
    ///
    /// ## Path Parameters
    /// - projectID: The unique identifier of the project
    ///
    /// ## Required Headers
    /// - Expects a bearer token object from Clerk. More information here: https://clerk.com/docs/react/reference/hooks/use-auth
    /// 
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID and project ID parameters
    /// - Returns: ``ProjectDTO`` object containing the project information
    @Sendable
    func get(req: Request) async throws -> ProjectDTO {
        let user = try req.auth.require(User.self)
        
        guard let projectID = req.parameters.get("projectID", as: UUID.self),
              let project = try await Project.query(on: req.db).filter(\.$id == projectID).filter(\.$user.$id == user.requireID()).with(\.$user).first() else {
            throw Abort(.notFound)
        }

        return try await project.toDTO(on: req.db)
    }

    /// DELETE /me/projects/:projectID
    /// 
    /// Deletes a specific project by its unique identifier.
    ///
    /// ## Path Parameters
    /// - projectID: The unique identifier of the project 
    ///
    /// ## Required Headers
    /// - Expects a bearer token object from Clerk. More information here: https://clerk.com/docs/react/reference/hooks/use-auth
    /// 
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID and project ID parameters
    /// - Returns: HTTP status code indicating the result of the deletion operation
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        guard let projectID = req.parameters.get("projectID", as: UUID.self),
              let project = try await Project.query(on: req.db).filter(\.$id == projectID).filter(\.$user.$id == user.requireID()).with(\.$user).first() else {
            throw Abort(.notFound)
        }

        try await project.delete(on: req.db)
        return .accepted
    }
}
