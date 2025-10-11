//
//  DeviceValidationMiddlewear.swift
//  APIProxy
//
//  Created by Morris Richman on 10/10/25.
//

import Foundation
import Vapor
import VaporDeviceCheck
import Fluent
import JWTKit

struct DeviceValidationMiddlewear: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let modeString = request.headers.first(name: DeviceValidationHeaderKeys.validationMode), let mode = DeviceValidationMode(rawValue: modeString) else {
            throw Abort(.unauthorized, reason: "Failed Device Validation: Mode not detected")
        }
        
        switch mode {
        case .deviceCheck:
            return try await handleDeviceCheck(to: request, chainingTo: next)
        }
    }
    
    private func handleDeviceCheck(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let teamID = request.headers.first(name: DeviceValidationHeaderKeys.appleTeamID) else {
            throw Abort(.unauthorized, reason: "Failed Device Validation: Team ID not detected")
        }
        guard let associationId = request.headers.first(name: ProxyHeaderKeys.associationId) else {
            throw Abort(.unauthorized, reason: "Failed Device Validation: Association ID not detected")
        }
        
        // Get Project so we can fetch the user
        guard let dbKey = try await APIKey.find(UUID(uuidString: associationId), on: request.db) else {
            throw Abort(.unauthorized, reason: "Key was not found")
        }
        try await dbKey.$project.load(on: request.db)
        let project = try await dbKey.$project.get(on: request.db)
        
        // Get User
        try await project.$user.load(on: request.db)
        let user = try await project.$user.get(on: request.db)
        
        // Get device check key within user
        guard let key = try await DeviceCheckKey.query(on: request.db).filter(\.$teamID == teamID).filter(\.$user.$id == user.requireID()).with(\.$user).first() else {
            throw Abort(.unauthorized, reason: "Key was not found")
        }
        
        let kid = JWKIdentifier(string: key.keyID)
        let privateKey = try ES256PrivateKey(pem: Data(key.secretKey.utf8))
        
        let deviceCheckMiddlewear = DeviceCheck(
            jwkKid: .init(string: key.keyID),
            jwkIss: key.teamID,
            excludes: [["health"]],
            bypassTokens: [key.bypassToken]
        )
        
        let promise = request.eventLoop.makePromise(of: Response.self)
        
        let deviceCheckEventLoopFuture = deviceCheckMiddlewear.respond(to: request, chainingTo: next)
        
        let response = try await withCheckedThrowingContinuation { continuation in
            deviceCheckEventLoopFuture.whenComplete { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        return response
    }
}

struct DeviceValidationHeaderKeys {
    static let validationMode = "APIProxy_VALIDATION_MODE"
    static let appleTeamID = "APIProxy_APPLE_TEAM_ID"
}

enum DeviceValidationMode: String, Codable, CaseIterable {
    case deviceCheck
}
