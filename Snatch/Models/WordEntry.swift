//
//  WordEntry.swift
//  Snatch
//
//  Data model for vocabulary items captured from clipboard.
//  Uses SwiftData for persistence and future CloudKit sync.
//

import Foundation
import SwiftData

/// A single vocabulary entry captured from pasted text or screenshot.
///
/// Each entry stores:
/// - The original word/phrase in the detected language
/// - The language it belongs to (mother tongue vs learning language)
/// - Example phrases showing real usage context
/// - Metadata for spaced-repetition flashcard scheduling
@Model
final class WordEntry {
    var word: String
    var languageCode: String          // e.g. "en", "ko", "ja", "zh"
    var exampleSentence: String
    var sourceText: String            // the full original pasted text for context
    var category: String              // auto-tagged category: "noun", "verb", "phrase", etc.

    // Flashcard scheduling (simple Leitner box system)
    var boxLevel: Int                 // 0-4, higher = more familiar
    var lastReviewedAt: Date?
    var nextReviewAt: Date?

    var createdAt: Date
    var isFavorite: Bool

    init(
        word: String,
        languageCode: String = "",
        exampleSentence: String = "",
        sourceText: String = "",
        category: String = "phrase",
        boxLevel: Int = 0,
        createdAt: Date = .now,
        isFavorite: Bool = false
    ) {
        self.word = word
        self.languageCode = languageCode
        self.exampleSentence = exampleSentence
        self.sourceText = sourceText
        self.category = category
        self.boxLevel = boxLevel
        self.lastReviewedAt = nil
        self.nextReviewAt = nil
        self.createdAt = createdAt
        self.isFavorite = isFavorite
    }
}

/// User's language pair configuration.
@Model
final class LanguageConfig {
    var motherTongueCode: String      // e.g. "ko"
    var learningLanguageCode: String  // e.g. "en"
    var updatedAt: Date

    init(motherTongueCode: String = "ko", learningLanguageCode: String = "en") {
        self.motherTongueCode = motherTongueCode
        self.learningLanguageCode = learningLanguageCode
        self.updatedAt = .now
    }
}
