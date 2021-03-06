import Foundation


struct DeletePasswordRequest {
    
    let credentials: Credentials
    let password: Password
    
}


extension DeletePasswordRequest: NCPasswordsRequest {
    
    func encode() -> Data? {
        try? JSONEncoder().encode(password)
    }
    
    func send(completion: @escaping (Response?) -> Void) {
        delete(action: "password/delete", credentials: credentials, completion: completion)
    }
    
    func decode(data: Data) -> Response? {
        try? JSONDecoder().decode(Response.self, from: data)
    }
    
}


extension DeletePasswordRequest {
    
    struct Response: Decodable {
        
        let id: String
        let revision: String
        
    }
    
}
