import Fluent
import Vapor

struct APIKeyRecievingDTO: Content {
    var id: UUID?
    var name: String?
    var apiKey: String
}

struct APIKeySendingDTO: Content {
    var id: UUID?
    var name: String?
}
