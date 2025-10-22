import Fluent
import Vapor

func routes(_ app: Application) throws {
app.get { req async in
        "It works!"
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
    
    try app.grouped(DeviceValidationMiddlewear()).register(collection: RequestProxyController())
    let authenticatedRouters = app.grouped(ClerkAuthenticator())
    
    try authenticatedRouters.register(collection: UserController())
    try authenticatedRouters.register(collection: APIKeyController())
    try authenticatedRouters.register(collection: ProjectController())
    try authenticatedRouters.register(collection: DeviceCheckKeyController())
}
