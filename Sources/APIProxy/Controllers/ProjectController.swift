import Fluent
import Vapor

struct ProjectController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let projects = routes.grouped("users", ":userID", "projects")

        projects.get(use: self.index)
        projects.post(use: self.create)
        projects.group(":projectID") { project in
            project.get(use: self.get)
            project.delete(use: self.delete)
        }
    }

    /// GET /users/:userID/projects
    /// 
    /// Retrieves all projects belonging to a specific user.
    /// 
    /// ## Path Parameters
    /// - userID: The unique identifier of the user
    /// 
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID parameter
    /// - Returns: Array of ``ProjectDTO`` objects containing project information
    @Sendable
    func index(req: Request) async throws -> [ProjectDTO] {
        guard let user = try await User.find(req.parameters.require("userID"), on: req.db) else {
            throw Abort(.unauthorized)
        }
        
        return try await Project.query(on: req.db).filter(\.$user.$id == user.requireID()).all().asyncMap { try await $0.toDTO(on: req.db) }
    }

    /// POST /users/:userID/projects
    /// 
    /// Creates a new project for a specific user.
    /// 
    /// ## Path Parameters
    /// - userID: The unique identifier of the user
    /// 
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID parameter and project data in the request body
    /// - Returns: ``ProjectDTO`` object containing the created project information
    @Sendable
    func create(req: Request) async throws -> ProjectDTO {
        let project = try req.content.decode(ProjectDTO.self).toModel()
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.badRequest, reason: "User Not Found")
        }

        project.$user.id = try user.requireID()
        
        try await project.save(on: req.db)
        return try await project.toDTO(on: req.db)
    }

    /// GET /users/:userID/projects/:projectID
    /// 
    /// Retrieves a specific project by its unique identifier.
    /// 
    /// ## Path Parameters
    /// - userID: The unique identifier of the user
    /// - projectID: The unique identifier of the project
    /// 
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID and project ID parameters
    /// - Returns: ``ProjectDTO`` object containing the project information
    @Sendable
    func get(req: Request) async throws -> ProjectDTO {
        guard let project = try await Project.find(req.parameters.get("projectID"), on: req.db) else {
            throw Abort(.notFound)
        }

        return try await project.toDTO(on: req.db)
    }

    /// DELETE /users/:userID/projects/:projectID
    /// 
    /// Deletes a specific project by its unique identifier.
    /// 
    /// ## Path Parameters
    /// - userID: The unique identifier of the user
    /// - projectID: The unique identifier of the project
    /// 
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID and project ID parameters
    /// - Returns: HTTP status code indicating the result of the deletion operation
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let project = try await Project.find(req.parameters.get("projectID"), on: req.db) else {
            throw Abort(.notFound)
        }

        try await project.delete(on: req.db)
        return .accepted
    }
}
