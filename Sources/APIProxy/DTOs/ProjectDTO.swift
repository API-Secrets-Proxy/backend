import Fluent
import Vapor

struct ProjectDTO: Content {
    var id: UUID?
    var name: String?
    
    func toModel() -> Project {
        let model = Project()
        
        model.id = self.id
        if let name = self.name {
            model.name = name
        }
        return model
    }
}
