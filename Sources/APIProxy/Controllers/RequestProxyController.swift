import Fluent
import Vapor

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct RequestProxyController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let keys = routes.grouped("proxy")

        keys.post(use: proxyRequest)
    }

    /// Proxies the request sent
    /// ## Headers
    ///   - APIProxy_ASSOCIATION_ID: The key id
    ///   - APIProxy_HTTP_METHOD: The method for the real request
    ///   - APIProxy_DESTINATION: The real url destination
    /// ## Including Your Partial Key
    /// Send your partial key like you would send any other key header to the service, but wrap it like so `%APIProxy_PARTIAL_KEY:<key>%`.
    /// This will be replaced with the full key and then sent to the real service.
    @Sendable
    func proxyRequest(req: Request) async throws -> ClientResponse {
        var headers = req.headers
        guard let associationId = headers.first(name: ProxyHeaderKeys.associationId) else { throw ProxyError.associationIdMissing }
        guard let partialKey = headers.first(where: { $0.value.contains(ProxyHeaderKeys.partialKeyIdentifier)}) else { throw ProxyError.partialKeyMissing }
        guard let httpMethod = headers.first(name: ProxyHeaderKeys.httpMethod) else { throw ProxyError.httpMethodMissing }
        guard let destinationString = headers.first(name: ProxyHeaderKeys.destination) else { throw ProxyError.destinationMissing }
        
        headers.remove(name: ProxyHeaderKeys.destination)
        headers.remove(name: ProxyHeaderKeys.httpMethod)
        headers.remove(name: ProxyHeaderKeys.associationId)
        headers.remove(name: "X-Apple-Device-Token")
        headers.remove(name: "Host")
        
        // Get Full Key
        guard let dbKey = try await APIKey.find(UUID(uuidString: associationId), on: req.db) else {
            throw Abort(.badRequest, reason: "Key was not found")
        }
        guard let userPartialKeyRange = partialKey.value.range(of: #"(?<=%APIProxy_PARTIAL_KEY:)[^%]+"#, options: .regularExpression) else {
            throw Abort(.badRequest, reason: "Partial Key was not found")
        }
        let userPartialKey = String(partialKey.value[userPartialKeyRange])
        let completeKey = try KeySplitter.reconstruct(serverShareB64: dbKey.partialKey, clientShareB64: userPartialKey)
        for header in headers where header.value.contains(ProxyHeaderKeys.partialKeyIdentifier) {
            headers.replaceOrAdd(name: header.name, value: header.value.replacingOccurrences(of: "\(ProxyHeaderKeys.partialKeyIdentifier)\(userPartialKey)%", with: completeKey))
        }
        
        let request = ClientRequest(method: .RAW(value: httpMethod), url: URI(string: destinationString), headers: headers, body: req.body.data)
        return try await req.client.send(request)
    }
}

private struct ProxyHeaderKeys {
    static let associationId = "APIProxy_ASSOCIATION_ID"
    static let httpMethod = "APIProxy_HTTP_METHOD"
    static let destination = "APIProxy_DESTINATION"
    static let partialKeyIdentifier = "%APIProxy_PARTIAL_KEY:"
    
}

private enum ProxyError: Error {
    case associationIdMissing, partialKeyMissing, httpMethodMissing, destinationMissing
}
