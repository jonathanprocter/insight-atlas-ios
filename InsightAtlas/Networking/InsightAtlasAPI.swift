//
//  InsightAtlasAPI.swift
//  InsightAtlas
//
//  API client for Insight Atlas backend services.
//
//  NOTE: This is an optional backend integration that is not required for
//  the main app functionality. The app uses direct AI provider APIs (Claude, OpenAI)
//  via AIService for summary generation. This backend API is only used for
//  the optional "Generate via Backend" feature in AnalysisDetailView.
//

import Foundation

/// Error types for backend API operations
enum InsightAtlasAPIError: LocalizedError {
    case backendNotConfigured
    case networkError(Error)
    case invalidResponse
    case serverError(Int, String?)

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured:
            return "Backend API is not configured. The app uses direct AI provider integration by default."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from backend server."
        case .serverError(let code, let message):
            if let msg = message {
                return "Server error (HTTP \(code)): \(msg)"
            }
            return "Server error (HTTP \(code))"
        }
    }
}

final class InsightAtlasAPI {
    static let shared = InsightAtlasAPI()
    private init() {}

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let iso8601FractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Backend URL - can be configured via environment variable or set directly
    /// If not configured, the backend features will gracefully report as unavailable
    private var baseURL: URL? {
        // Check for environment variable first (useful for development/testing)
        if let urlString = ProcessInfo.processInfo.environment["INSIGHT_ATLAS_API_URL"],
           let url = URL(string: urlString) {
            return url
        }

        // Placeholder URL indicates backend is not configured
        // In a production deployment, this would be replaced with the actual URL
        return nil
    }

    /// Check if the backend API is configured and available
    var isConfigured: Bool {
        baseURL != nil
    }

    func generateGuide(
        request: GenerateGuideRequest
    ) async throws -> GenerateGuideResponse {
        guard let baseURL = baseURL else {
            throw InsightAtlasAPIError.backendNotConfigured
        }

        let url = baseURL.appendingPathComponent("generate")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120 // 2 minute timeout for generation

        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw InsightAtlasAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InsightAtlasAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8)
            throw InsightAtlasAPIError.serverError(httpResponse.statusCode, message)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let dateString = try? container.decode(String.self) {
                if let date = InsightAtlasAPI.iso8601FractionalFormatter.date(from: dateString) {
                    return date
                }
                if let date = InsightAtlasAPI.iso8601Formatter.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO-8601 date string: \(dateString)"
                )
            }
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            if let timestamp = try? container.decode(Int.self) {
                return Date(timeIntervalSince1970: Double(timestamp))
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date value"
            )
        }
        return try decoder.decode(GenerateGuideResponse.self, from: data)
    }
}
