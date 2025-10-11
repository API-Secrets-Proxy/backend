//
//  Cors.swift
//  APIProxy
//
//  Created by Morris Richman on 10/10/25.
//

import Foundation
import Vapor

private let corsConfiguration = CORSMiddleware.Configuration(
    allowedOrigin: .any(["http://127.0.0.1:5500"]),
    allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
    allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
)
let corsMiddlewear = CORSMiddleware(configuration: corsConfiguration)
