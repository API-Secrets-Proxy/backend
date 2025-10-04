//
//  ConfigurationError.swift
//  Assignment-Manager-API
//
//  Created by Morris Richman on 7/27/25.
//

import Vapor
import JWTKit
import VaporDeviceCheck

enum ConfigurationError: Error {
    case noAppleJwtPrivateKey, noAppleJwtKid, noAppleJwtIss
}

// configures your application
public func configureDeviceCheck(_ app: Application) async throws {
    guard let jwtPrivateKeyStringEscaped = Environment.get("APPLE_JWT_PRIVATE_KEY") else {
        throw ConfigurationError.noAppleJwtPrivateKey
    }
    let jwtPrivateKeyString = jwtPrivateKeyStringEscaped.replacingOccurrences(of: "\\n", with: "\n")
    
    guard let jwtKidString = Environment.get("APPLE_JWT_KID") else {
        throw ConfigurationError.noAppleJwtKid
    }
    guard let jwtIss = Environment.get("APPLE_JWT_ISS") else {
        throw ConfigurationError.noAppleJwtIss
    }
    
    let jwtBypassToken = Environment.get("APPLE_JWT_BYPASS_TOKEN")

    let kid = JWKIdentifier(string: jwtKidString)
    let privateKey = try ES256PrivateKey(pem: Data(jwtPrivateKeyString.utf8))

    // Add ECDSA key with JWKIdentifier
    await app.jwt.keys.add(ecdsa: privateKey, kid: kid)

    deviceCheckMiddleware = DeviceCheck(
        jwkKid: kid,
        jwkIss: jwtIss,
        excludes: [["health"]],
        bypassTokens: jwtBypassToken == nil ? [] : [jwtBypassToken!]
    )
}

nonisolated(unsafe) fileprivate var deviceCheckMiddleware: DeviceCheck?

extension RoutesBuilder {
    var deviceCheck: any RoutesBuilder {
        if let deviceCheckMiddleware {
            return self.grouped(deviceCheckMiddleware)
        } else {
            fatalError("Device check middleware not configured.")
        }
    }
}
