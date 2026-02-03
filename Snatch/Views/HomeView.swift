//
//  HomeView.swift
//  Snatch
//
//  THE home screen. This is what the user sees when they open the app.
//  It's intentionally minimal: a blank paste area.
//
//  Design principle: ZERO latency. No database queries, no network calls,
//  no heavy view hierarchies on launch. Just a blank area waiting for
//  Cmd+V. Everything else (word list, flashcards) loads lazily when
//  the user navigates to those tabs.
//
//  Two ways to use:
//  1. Cmd+V to paste text → auto-detects languages, shows candidates
//  2. Cmd+V to paste screenshot → OCR extracts text → same flow
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [LanguageConfig]

    @State private var pastedText = ""
    @State private var candidates: [WordCandidate] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showResults = false
    @State private var droppedImage: NSImage?
    @FocusState private var isFocused: Bool

    private var config: LanguageConfig? { configs.first }

    var body: some View {
        VStack(spacing: 0) {
            if showResults {
                resultsView
            } else {
                pasteArea
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Paste Area (the blank home screen)

    private var pasteArea: some View {
        VStack(spacing: 16) {
            Spacer()

            if isProcessing {
                ProgressView("Recognizing text...")
                    .controlSize(.large)
            } else {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundStyle(.tertiary)

                Text("Paste text or screenshot")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("⌘V")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.separatorColor).opacity(0.3))
                    )

                // Manual paste button as fallback
                Button("Paste from Clipboard") {
                    handleDirectPaste()
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .focusable()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onDrop(of: [.image, .text], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
        .onCopyCommand { return [] } // Enable Edit menu
        .onPasteCommand(of: [UTType.png, UTType.tiff, UTType.plainText]) { _ in
            handleDirectPaste()
        }
    }

    // MARK: - Results View (after paste)

    private var resultsView: some View {
        VStack(spacing: 0) {
            // Header with source text
            HStack {
                Text("Detected Content")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showResults = false
                        candidates = []
                        pastedText = ""
                        droppedImage = nil
                    }
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // Source text preview
            if !pastedText.isEmpty {
                ScrollView {
                    Text(pastedText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 120)
                .background(Color(.textBackgroundColor).opacity(0.5))

                Divider()
            }

            // Candidate list
            if candidates.isEmpty {
                VStack {
                    Spacer()
                    Text("No words detected")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(candidates) { candidate in
                        CandidateRow(candidate: candidate) {
                            saveCandidate(candidate)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Actions

    /// Direct clipboard read - more reliable than NSItemProvider on macOS
    private func handleDirectPaste() {
        isProcessing = true
        errorMessage = nil

        let pasteboard = NSPasteboard.general

        // Try image first (screenshots)
        if let image = NSImage(pasteboard: pasteboard) {
            Task {
                await processImage(image)
            }
            return
        }

        // Then try text
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            processText(text)
            return
        }

        // Nothing found
        errorMessage = "Clipboard is empty"
        isProcessing = false
    }

    private func handlePaste(_ providers: [NSItemProvider]) {
        isProcessing = true
        errorMessage = nil

        // Try image first
        if let imageProvider = providers.first(where: { $0.canLoadObject(ofClass: NSImage.self) }) {
            imageProvider.loadObject(ofClass: NSImage.self) { object, error in
                Task { @MainActor in
                    if let image = object as? NSImage {
                        await processImage(image)
                    } else {
                        self.errorMessage = error?.localizedDescription ?? "Failed to load image"
                        self.isProcessing = false
                    }
                }
            }
            return
        }

        // Try text
        if let textProvider = providers.first(where: { $0.canLoadObject(ofClass: String.self) }) {
            textProvider.loadObject(ofClass: String.self) { object, error in
                Task { @MainActor in
                    if let text = object as? String {
                        processText(text)
                    } else {
                        self.errorMessage = error?.localizedDescription ?? "Failed to load text"
                        self.isProcessing = false
                    }
                }
            }
            return
        }

        isProcessing = false
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        isProcessing = true
        errorMessage = nil

        if let imageProvider = providers.first(where: { $0.canLoadObject(ofClass: NSImage.self) }) {
            imageProvider.loadObject(ofClass: NSImage.self) { object, _ in
                Task { @MainActor in
                    if let image = object as? NSImage {
                        await processImage(image)
                    }
                }
            }
        }
    }

    private func processImage(_ image: NSImage) async {
        droppedImage = image
        do {
            let text = try await OCRService.recognizeText(from: image)
            processText(text)
        } catch {
            errorMessage = error.localizedDescription
            isProcessing = false
        }
    }

    private func processText(_ text: String) {
        pastedText = text
        let motherTongue = config?.motherTongueCode ?? "ko"
        let learningLang = config?.learningLanguageCode ?? "en"

        candidates = LanguageService.organizeText(
            text,
            motherTongue: motherTongue,
            learningLanguage: learningLang
        )

        isProcessing = false
        withAnimation(.easeInOut(duration: 0.2)) {
            showResults = true
        }
    }

    private func saveCandidate(_ candidate: WordCandidate) {
        let entry = WordEntry(
            word: candidate.text,
            languageCode: candidate.languageCode,
            exampleSentence: candidate.text,
            sourceText: candidate.fullSourceText,
            category: candidate.isLearningLanguage ? "learning" : "native"
        )
        modelContext.insert(entry)
        try? modelContext.save()

        // Remove from candidates list
        withAnimation {
            candidates.removeAll { $0.id == candidate.id }
        }
    }
}

// MARK: - Candidate Row

private struct CandidateRow: View {
    let candidate: WordCandidate
    let onSave: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.text)
                    .font(.body)

                HStack(spacing: 8) {
                    Text(candidate.languageCode.uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(candidate.isLearningLanguage
                                      ? Color.blue.opacity(0.15)
                                      : Color.gray.opacity(0.15))
                        )

                    Text(candidate.isLearningLanguage ? "Learning" : "Native")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                onSave()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)
            .help("Save to word list")
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [WordEntry.self, LanguageConfig.self], inMemory: true)
}
