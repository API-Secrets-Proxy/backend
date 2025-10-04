import Fluent
import Vapor

struct UserDTO: Content {
    var id: UUID?
    var name: String?
    let projects: [ProjectDTO]?
    
    func toModel() -> User {
        let model = User()
        
        model.id = self.id
        if let name = self.name {
            model.name = name
        }
        return model
    }
}
