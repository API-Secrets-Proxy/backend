import Fluent
import Vapor
import JWTKit

struct DeviceCheckKeyController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let keys = routes.grouped("me", "device-check")

        keys.get(use: self.index)
        keys.post(use: self.create)
        keys.group(":teamID") { key in
            key.get(use: self.get)
            key.delete(use: self.delete)
        }
    }

    /// GET /me/device-check
    ///
    /// Retrieves all DeviceCheck keys for a specific user.
    /// 
    /// ## Request Headers
    /// Expects a bearer token object from Clerk. More information here: https://clerk.com/docs/react/reference/hooks/use-auth
    ///
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID parameter
    /// - Returns: Array of ``DeviceCheckKeySendingDTO`` objects containing DeviceCheck key information
    @Sendable
    func index(req: Request) async throws -> [DeviceCheckKeySendingDTO] {
        let user = try req.auth.require(User.self)
        
        return try await DeviceCheckKey.query(on: req.db).filter(\.$user.$id == user.requireID()).with(\.$user).all().map { $0.toDTO() }
    }

    /// POST /me/device-check
    ///
    /// Creates or updates a DeviceCheck key for a specific user and team.
    /// 
    /// ## Request Headers
    /// Expects a bearer token object from Clerk. More information here: https://clerk.com/docs/react/reference/hooks/use-auth
    ///
    /// ## Request Body
    /// Expects a ``DeviceCheckKeyRecievingDTO`` object containing:
    /// - teamID: The Apple Developer team identifier (required)
    /// - keyID: The Apple Developer key identifier (required)
    /// - privateKey: The ES256 private key in PEM format (required)
    /// 
    /// ```json
    /// {
    ///   "teamID": "XYZ789GHI0",
    ///   "keyID": "ABC123DEF4",
    ///   "privateKey": "-----BEGIN PRIVATE KEY-----\nMIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg...\n-----END PRIVATE KEY-----"
    /// }
    /// ```
    /// 
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID parameter and DeviceCheck key data in the request body
    /// - Returns: ``DeviceCheckKeySendingDTO`` object containing the DeviceCheck key information
    @Sendable
    func create(req: Request) async throws -> DeviceCheckKeySendingDTO {
        let user = try req.auth.require(User.self)
        
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

    /// GET /me/device-check/:teamID
    ///
    /// Retrieves a specific DeviceCheck key by team ID for a user.
    ///
    /// ## Request Headers
    /// Expects a bearer token object from Clerk. More information here: https://clerk.com/docs/react/reference/hooks/use-auth
    ///
    /// ## Path Parameters
    /// - teamID: The unique identifier of the Apple Developer team
    ///
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID and team ID parameters
    /// - Returns: ``DeviceCheckKeySendingDTO`` object containing the DeviceCheck key information
    @Sendable
    func get(req: Request) async throws -> DeviceCheckKeySendingDTO {
        let user = try req.auth.require(User.self)

        guard let key = try await DeviceCheckKey.query(on: req.db).filter(\.$teamID == req.parameters.require("teamID")).filter(\.$user.$id == user.requireID()).with(\.$user).first() else {
            throw Abort(.notFound, reason: "DeviceCheck Key was Not Found")
        }
        return key.toDTO()
    }

    /// DELETE /me/device-check/:teamID
    ///
    /// Deletes a specific DeviceCheck key by team ID for a user.
    ///
    /// ## Request Headers
    /// Expects a bearer token object from Clerk. More information here: https://clerk.com/docs/react/reference/hooks/use-auth
    /// 
    /// ## Path Parameters
    /// - teamID: The unique identifier of the Apple Developer team
    ///
    /// - Parameters:
    ///   - req: The HTTP request containing the user ID and team ID parameters
    /// - Returns: HTTP status code indicating the result of the deletion operation
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)

        guard let key = try await DeviceCheckKey.query(on: req.db).filter(\.$teamID == req.parameters.require("teamID")).filter(\.$user.$id == user.requireID()).with(\.$user).first() else {
            throw Abort(.notFound, reason: "DeviceCheck Key was Not Found")
        }

        try await key.delete(on: req.db)
        return .accepted
    }
}
