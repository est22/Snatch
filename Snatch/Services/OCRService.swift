//
//  OCRService.swift
//  Snatch
//
//  Uses Apple's Vision framework to extract text from images (screenshots).
//  Runs entirely on-device - no API keys, no network, no cost.
//
//  HOW IT WORKS:
//  1. You paste a screenshot into the app
//  2. Vision's VNRecognizeTextRequest scans the image
//  3. Returns all recognized text strings
//
//  Supports multiple languages simultaneously - if your screenshot has
//  both Korean and English, it will recognize both.
//

import Vision
import AppKit

struct OCRService {

    /// Recognize all text in an NSImage (from clipboard screenshot).
    /// Returns the full recognized text as a single string.
    static func recognizeText(from image: NSImage) async throws -> String {
        guard let cgImage = image.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ) else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                continuation.resume(returning: text)
            }

            // Enable accurate recognition and support all available languages
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // Automatic language detection - Vision handles multilingual text
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum OCRError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image for text recognition."
        }
    }
}
