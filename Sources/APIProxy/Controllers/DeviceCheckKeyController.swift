import Fluent
import Vapor
import JWTKit

struct DeviceCheckKeyController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let keys = routes.grouped("users", ":userID", "device-check")

        keys.get(use: self.index)
        keys.post(use: self.create)
        keys.group(":teamID") { key in
            key.get(use: self.get)
            key.delete(use: self.delete)
        }
    }

    @Sendable
    func index(req: Request) async throws -> [DeviceCheckKeySendingDTO] {
        guard let user = try await User.find(req.parameters.require("userID"), on: req.db) else {
            throw Abort(.unauthorized)
        }
        
        return try await DeviceCheckKey.query(on: req.db).filter(\.$user.$id == user.requireID()).with(\.$user).all().map { $0.toDTO() }
    }

    @Sendable
    func create(req: Request) async throws -> DeviceCheckKeySendingDTO {
        guard let user = try await User.find(req.parameters.require("userID"), on: req.db) else {
            throw Abort(.unauthorized)
        }
        
        let dto = try req.content.decode(DeviceCheckKeyRecievingDTO.self)
        
        // Validate key is correct form
        let _ = try ES256PrivateKey(pem: Data(dto.privateKey.utf8))
        
        // Update Existing Key or Create New ONe
        let key: DeviceCheckKey
        
        if let foundKey = (try? await DeviceCheckKey.query(on: req.db).filter(\.$teamID == dto.teamID).filter(\.$user.$id == user.requireID()).with(\.$user).first()) {
            foundKey.secretKey = dto.privateKey
            foundKey.keyID = dto.keyID
            key = foundKey
        } else {
            key = DeviceCheckKey(secretKey: dto.privateKey, keyID: dto.keyID, teamID: dto.teamID)
        }
        
        // Assign to user and save
        key.$user.id = try user.requireID()
        try await key.save(on: req.db)
        
        return key.toDTO()
    }

    @Sendable
    func get(req: Request) async throws -> DeviceCheckKeySendingDTO {
        guard let user = try await User.find(req.parameters.require("userID"), on: req.db) else {
            throw Abort(.unauthorized)
        }

        guard let key = try await DeviceCheckKey.query(on: req.db).filter(\.$teamID == req.parameters.require("teamID")).filter(\.$user.$id == user.requireID()).with(\.$user).first() else {
            throw Abort(.notFound, reason: "DeviceCheck Key was Not Found")
        }
        return key.toDTO()
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let user = try await User.find(req.parameters.require("userID"), on: req.db) else {
            throw Abort(.unauthorized)
        }

        guard let key = try await DeviceCheckKey.query(on: req.db).filter(\.$teamID == req.parameters.require("teamID")).filter(\.$user.$id == user.requireID()).with(\.$user).first() else {
            throw Abort(.notFound, reason: "DeviceCheck Key was Not Found")
        }

        try await key.delete(on: req.db)
        return .accepted
    }
}
