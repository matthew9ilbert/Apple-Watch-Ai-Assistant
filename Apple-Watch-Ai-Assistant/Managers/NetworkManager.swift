import Foundation
import Network

class NetworkManager {
    static let shared = NetworkManager()
    
    // MARK: - Properties
    
    private let session: URLSession
    private let monitor = NWPathMonitor()
    private let analyticsManager = AnalyticsManager.shared
    
    @Published var isOnline = true
    @Published var connectionType: ConnectionType = .unknown
    
    // MARK: - Types
    
    enum ConnectionType {
        case wifi
        case cellular
        case unknown
    }
    
    enum NetworkError: LocalizedError {
        case invalidURL
        case noNetwork
        case invalidResponse
        case requestFailed(Error)
        case decodingFailed(Error)
        case rateLimitExceeded
        case unauthorized
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .noNetwork:
                return "No network connection"
            case .invalidResponse:
                return "Invalid server response"
            case .requestFailed(let error):
                return "Request failed: \(error.localizedDescription)"
            case .decodingFailed(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            case .rateLimitExceeded:
                return "API rate limit exceeded"
            case .unauthorized:
                return "Unauthorized access"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Configure URL session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
        
        // Setup network monitoring
        setupNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                self?.connectionType = self?.determineConnectionType(path) ?? .unknown
                
                self?.analyticsManager.logEvent(
                    "network_status_changed",
                    category: .settings,
                    parameters: [
                        "online": "\(path.status == .satisfied)",
                        "type": "\(self?.connectionType ?? .unknown)"
                    ]
                )
            }
        }
        
        monitor.start(queue: DispatchQueue.global())
    }
    
    private func determineConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        }
        return .unknown
    }
    
    // MARK: - Network Operations
    
    func fetch<T: Decodable>(_ type: T.Type,
                            from endpoint: Endpoint,
                            cachePolicy: URLRequest.CachePolicy? = nil) async throws -> T {
        guard isOnline else {
            throw NetworkError.noNetwork
        }
        
        do {
            let request = try endpoint.urlRequest()
            if let cachePolicy = cachePolicy {
                request.cachePolicy = cachePolicy
            }
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Handle response status
            switch httpResponse.statusCode {
            case 200...299:
                break // Success
            case 401:
                throw NetworkError.unauthorized
            case 429:
                throw NetworkError.rateLimitExceeded
            default:
                throw NetworkError.invalidResponse
            }
            
            // Log request metrics
            logRequestMetrics(endpoint: endpoint, statusCode: httpResponse.statusCode)
            
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            throw NetworkError.decodingFailed(error)
        } catch {
            throw NetworkError.requestFailed(error)
        }
    }
    
    func uploadData(_ data: Data,
                   to endpoint: Endpoint,
                   method: HTTPMethod = .post) async throws -> URLResponse {
        guard isOnline else {
            throw NetworkError.noNetwork
        }
        
        var request = try endpoint.urlRequest()
        request.httpMethod = method.rawValue
        request.httpBody = data
        
        do {
            let (_, response) = try await session.upload(for: request, from: data)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Log upload metrics
            logRequestMetrics(endpoint: endpoint,
                            statusCode: httpResponse.statusCode,
                            dataSize: data.count)
            
            return response
        } catch {
            throw NetworkError.requestFailed(error)
        }
    }
    
    func download(from endpoint: Endpoint) async throws -> (Data, URLResponse) {
        guard isOnline else {
            throw NetworkError.noNetwork
        }
        
        do {
            let request = try endpoint.urlRequest()
            let (data, response) = try await session.data(for: request)
            
            // Log download metrics
            logRequestMetrics(endpoint: endpoint,
                            statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                            dataSize: data.count)
            
            return (data, response)
        } catch {
            throw NetworkError.requestFailed(error)
        }
    }
    
    // MARK: - Request Building
    
    struct Endpoint {
        let path: String
        let queryItems: [URLQueryItem]?
        let baseURL: URL
        let headers: [String: String]?
        
        init(path: String,
             queryItems: [URLQueryItem]? = nil,
             baseURL: URL = URL(string: "https://api.example.com")!,
             headers: [String: String]? = nil) {
            self.path = path
            self.queryItems = queryItems
            self.baseURL = baseURL
            self.headers = headers
        }
        
        func urlRequest() throws -> URLRequest {
            var components = URLComponents(url: baseURL.appendingPathComponent(path),
                                        resolvingAgainstBaseURL: true)
            components?.queryItems = queryItems
            
            guard let url = components?.url else {
                throw NetworkError.invalidURL
            }
            
            var request = URLRequest(url: url)
            headers?.forEach { request.addValue($1, forHTTPHeaderField: $0) }
            return request
        }
    }
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
    
    // MARK: - Analytics
    
    private func logRequestMetrics(endpoint: Endpoint,
                                 statusCode: Int,
                                 dataSize: Int? = nil) {
        var parameters: [String: String] = [
            "path": endpoint.path,
            "status_code": "\(statusCode)",
            "connection_type": "\(connectionType)"
        ]
        
        if let dataSize = dataSize {
            parameters["data_size"] = "\(dataSize)"
        }
        
        analyticsManager.logEvent(
            "network_request",
            category: .settings,
            parameters: parameters
        )
    }
    
    // MARK: - Caching
    
    func clearCache() {
        URLCache.shared.removeAllCachedResponses()
    }
    
    func clearCache(for endpoint: Endpoint) throws {
        let request = try endpoint.urlRequest()
        URLCache.shared.removeCachedResponse(for: request)
    }
    
    // MARK: - Rate Limiting
    
    private var rateLimits: [String: RateLimit] = [:]
    
    struct RateLimit {
        let requests: Int
        let timeWindow: TimeInterval
        private var timestamps: [Date] = []
        
        mutating func canMakeRequest() -> Bool {
            let now = Date()
            timestamps = timestamps.filter { now.timeIntervalSince($0) < timeWindow }
            guard timestamps.count < requests else { return false }
            timestamps.append(now)
            return true
        }
    }
    
    func setRateLimit(for endpoint: String, requests: Int, timeWindow: TimeInterval) {
        rateLimits[endpoint] = RateLimit(requests: requests, timeWindow: timeWindow)
    }
    
    func checkRateLimit(for endpoint: String) -> Bool {
        guard var rateLimit = rateLimits[endpoint] else { return true }
        let canProceed = rateLimit.canMakeRequest()
        rateLimits[endpoint] = rateLimit
        return canProceed
    }
}

// MARK: - Convenience Extensions

extension NetworkManager {
    // Weather API
    func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        let endpoint = Endpoint(
            path: "/weather",
            queryItems: [
                URLQueryItem(name: "lat", value: "\(latitude)"),
                URLQueryItem(name: "lon", value: "\(longitude)")
            ]
        )
        return try await fetch(WeatherData.self, from: endpoint)
    }
    
    // AI Assistant API
    func fetchAIResponse(prompt: String) async throws -> String {
        let endpoint = Endpoint(
            path: "/ai/chat",
            queryItems: nil,
            headers: ["Content-Type": "application/json"]
        )
        
        let requestData = try JSONEncoder().encode(["prompt": prompt])
        let request = try endpoint.urlRequest()
        
        let (data, _) = try await session.upload(for: request, from: requestData)
        let response = try JSONDecoder().decode(AIResponse.self, from: data)
        return response.text
    }
    
    private struct AIResponse: Codable {
        let text: String
    }
}
