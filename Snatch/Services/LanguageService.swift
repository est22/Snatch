//
//  LanguageService.swift
//  Snatch
//
//  Uses Apple's NaturalLanguage framework to:
//  1. Detect which language a piece of text is in
//  2. Split mixed-language text into segments by language
//  3. Extract individual words/phrases grouped by language
//
//  Runs entirely on-device. NLLanguageRecognizer is fast and accurate
//  for the common case of two languages mixed together (e.g. English
//  notes with Korean vocabulary).
//

import NaturalLanguage

struct LanguageService {

    /// Detect the dominant language of a text string.
    /// Returns an ISO 639-1 code like "en", "ko", "ja", "zh-Hans".
    static func detectLanguage(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }

    /// Split text into segments, each tagged with its detected language.
    /// This is how we separate "mother tongue" from "learning language"
    /// when a user pastes mixed-language content.
    ///
    /// Example input:  "Hello world. 안녕하세요."
    /// Example output: [("Hello world.", "en"), ("안녕하세요.", "ko")]
    static func segmentByLanguage(_ text: String) -> [(text: String, languageCode: String)] {
        let tagger = NLTagger(tagSchemes: [.language])
        tagger.string = text

        var segments: [(text: String, languageCode: String)] = []

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .sentence,
            scheme: .language
        ) { tag, range in
            let segment = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !segment.isEmpty else { return true }
            let lang = tag?.rawValue ?? "und" // "und" = undetermined
            segments.append((text: segment, languageCode: lang))
            return true
        }

        return segments
    }

    /// Extract individual words from text, grouped by language.
    /// Useful for building vocabulary lists from pasted content.
    static func extractWords(_ text: String) -> [(word: String, languageCode: String)] {
        let tagger = NLTagger(tagSchemes: [.language, .lexicalClass])
        tagger.string = text

        var words: [(word: String, languageCode: String)] = []

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .language
        ) { tag, range in
            let word = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty, word.count > 1 else { return true }
            let lang = tag?.rawValue ?? "und"
            words.append((word: word, languageCode: lang))
            return true
        }

        return words
    }

    /// Given a block of text, produce organized WordEntry candidates.
    /// Groups by language, extracts phrases (sentences) as example usage.
    static func organizeText(
        _ text: String,
        motherTongue: String,
        learningLanguage: String
    ) -> [WordCandidate] {
        let segments = segmentByLanguage(text)
        var candidates: [WordCandidate] = []

        for segment in segments {
            // Only capture words in the learning language
            let normalizedLang = normalizeLanguageCode(segment.languageCode)
            let isLearningLang = normalizedLang == normalizeLanguageCode(learningLanguage)
            let isMotherTongue = normalizedLang == normalizeLanguageCode(motherTongue)

            if isLearningLang || isMotherTongue {
                candidates.append(WordCandidate(
                    text: segment.text,
                    languageCode: normalizedLang,
                    isLearningLanguage: isLearningLang,
                    fullSourceText: text
                ))
            }
        }

        return candidates
    }

    /// Normalize language codes (e.g. "zh-Hans" -> "zh", "en-US" -> "en")
    private static func normalizeLanguageCode(_ code: String) -> String {
        String(code.prefix(2))
    }
}

/// A candidate word/phrase before the user confirms saving it.
struct WordCandidate: Identifiable {
    let id = UUID()
    let text: String
    let languageCode: String
    let isLearningLanguage: Bool
    let fullSourceText: String
}
