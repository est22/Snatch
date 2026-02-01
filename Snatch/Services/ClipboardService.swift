//
//  ClipboardService.swift
//  Snatch
//
//  Handles reading from the macOS clipboard (NSPasteboard).
//  Detects whether the user pasted text or an image, and routes
//  accordingly:
//  - Text → goes directly to LanguageService for segmentation
//  - Image → goes to OCRService first, then to LanguageService
//
//  On macOS, NSPasteboard is the system clipboard. When you Cmd+V,
//  the app reads from NSPasteboard.general.
//

import AppKit
import SwiftUI

/// What was on the clipboard when the user pasted.
enum ClipboardContent {
    case text(String)
    case image(NSImage)
    case empty
}

struct ClipboardService {

    /// Read current clipboard contents. Returns text or image.
    static func read() -> ClipboardContent {
        let pasteboard = NSPasteboard.general

        // Check for image first (screenshots are images)
        if let image = NSImage(pasteboard: pasteboard) {
            return .image(image)
        }

        // Then check for text
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return .text(text)
        }

        return .empty
    }

    /// Process clipboard content: extract text (via OCR if image),
    /// then organize by language.
    static func processClipboard(
        motherTongue: String,
        learningLanguage: String
    ) async throws -> ProcessedClipboard {
        let content = read()

        switch content {
        case .text(let text):
            let candidates = LanguageService.organizeText(
                text,
                motherTongue: motherTongue,
                learningLanguage: learningLanguage
            )
            return ProcessedClipboard(
                rawText: text,
                candidates: candidates,
                sourceType: .text
            )

        case .image(let image):
            let recognizedText = try await OCRService.recognizeText(from: image)
            let candidates = LanguageService.organizeText(
                recognizedText,
                motherTongue: motherTongue,
                learningLanguage: learningLanguage
            )
            return ProcessedClipboard(
                rawText: recognizedText,
                candidates: candidates,
                sourceType: .screenshot
            )

        case .empty:
            return ProcessedClipboard(
                rawText: "",
                candidates: [],
                sourceType: .text
            )
        }
    }
}

/// Result of processing clipboard content.
struct ProcessedClipboard {
    let rawText: String
    let candidates: [WordCandidate]
    let sourceType: SourceType

    enum SourceType {
        case text
        case screenshot
    }
}
