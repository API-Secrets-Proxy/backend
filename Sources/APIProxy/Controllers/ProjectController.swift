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

    @Sendable
    func index(req: Request) async throws -> [ProjectDTO] {
        try await Project.query(on: req.db).all().asyncMap { try await $0.toDTO(on: req.db) }
    }

    @Sendable
    func create(req: Request) async throws -> ProjectDTO {
        let project = try req.content.decode(ProjectDTO.self).toModel()
        guard let user = try await User.find(req.parameters.get("projectID"), on: req.db) else {
            throw Abort(.badRequest, reason: "User Not Found")
        }

        project.$user.id = try user.requireID()
        
        try await project.save(on: req.db)
        return try await project.toDTO(on: req.db)
    }

    @Sendable
    func get(req: Request) async throws -> ProjectDTO {
        guard let project = try await Project.find(req.parameters.get("projectID"), on: req.db) else {
            throw Abort(.notFound)
        }

        return try await project.toDTO(on: req.db)
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let project = try await Project.find(req.parameters.get("projectID"), on: req.db) else {
            throw Abort(.notFound)
        }

        try await project.delete(on: req.db)
        return .noContent
    }
}
