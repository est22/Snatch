//
//  FlashcardView.swift
//  Snatch
//
//  Flashcard review using a simple Leitner box system.
//  LAZY-LOADED - only initializes when user taps the Flashcard tab.
//
//  Leitner system (5 boxes):
//  - Box 0: New/unknown words → review every session
//  - Box 1: Review every 1 day
//  - Box 2: Review every 3 days
//  - Box 3: Review every 7 days
//  - Box 4: Mastered → review every 14 days
//
//  Correct answer → move up one box
//  Wrong answer → move back to box 0
//

import SwiftUI
import SwiftData

struct FlashcardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WordEntry.createdAt) private var allEntries: [WordEntry]

    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var reviewQueue: [WordEntry] = []
    @State private var sessionComplete = false

    private var currentCard: WordEntry? {
        guard currentIndex < reviewQueue.count else { return nil }
        return reviewQueue[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Flashcards")
                    .font(.headline)
                Spacer()
                if !reviewQueue.isEmpty {
                    Text("\(currentIndex + 1) / \(reviewQueue.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            // Card area
            if sessionComplete {
                sessionCompleteView
            } else if let card = currentCard {
                cardView(card)
            } else {
                emptyView
            }
        }
        .onAppear {
            buildReviewQueue()
        }
    }

    // MARK: - Card View

    private func cardView(_ card: WordEntry) -> some View {
        VStack {
            Spacer()

            // The flashcard
            VStack(spacing: 20) {
                if isFlipped {
                    // Back: show example sentence and source
                    VStack(spacing: 12) {
                        Text(card.word)
                            .font(.title2)
                            .fontWeight(.bold)

                        if !card.exampleSentence.isEmpty {
                            Text(card.exampleSentence)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Text(card.languageCode.uppercased())
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.blue.opacity(0.1)))
                    }
                } else {
                    // Front: show the word only
                    Text(card.word)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: 400, minHeight: 200)
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.textBackgroundColor))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isFlipped.toggle()
                }
            }

            Spacer()

            // Controls
            if isFlipped {
                HStack(spacing: 40) {
                    Button {
                        markWrong(card)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.red)
                            Text("Again")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut("1", modifiers: [])

                    Button {
                        markCorrect(card)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                            Text("Got it")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut("2", modifiers: [])
                }
                .padding(.bottom, 40)
            } else {
                Text("Tap card or press Space to reveal")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 40)
                    .onKeyPress(.space) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isFlipped.toggle()
                        }
                        return .handled
                    }
            }
        }
    }

    // MARK: - Empty / Complete states

    private var emptyView: some View {
        VStack {
            Spacer()
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text("No cards to review")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Save words from the Home tab to start")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private var sessionCompleteView: some View {
        VStack {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Session Complete!")
                .font(.title2)
                .fontWeight(.bold)
            Text("Reviewed \(reviewQueue.count) cards")
                .foregroundStyle(.secondary)

            Button("Review Again") {
                sessionComplete = false
                currentIndex = 0
                isFlipped = false
                buildReviewQueue()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)

            Spacer()
        }
    }

    // MARK: - Review Logic

    private func buildReviewQueue() {
        let now = Date.now
        reviewQueue = allEntries.filter { entry in
            guard let nextReview = entry.nextReviewAt else {
                return true // never reviewed = needs review
            }
            return nextReview <= now
        }
        .shuffled()
        currentIndex = 0
        sessionComplete = reviewQueue.isEmpty && !allEntries.isEmpty ? false : false
    }

    private func markCorrect(_ card: WordEntry) {
        card.boxLevel = min(card.boxLevel + 1, 4)
        card.lastReviewedAt = .now
        card.nextReviewAt = nextReviewDate(for: card.boxLevel)
        try? modelContext.save()
        advance()
    }

    private func markWrong(_ card: WordEntry) {
        card.boxLevel = 0
        card.lastReviewedAt = .now
        card.nextReviewAt = .now // review again immediately next session
        try? modelContext.save()
        advance()
    }

    private func advance() {
        isFlipped = false
        if currentIndex + 1 < reviewQueue.count {
            withAnimation {
                currentIndex += 1
            }
        } else {
            withAnimation {
                sessionComplete = true
            }
        }
    }

    private func nextReviewDate(for boxLevel: Int) -> Date {
        let intervals: [TimeInterval] = [
            0,              // box 0: immediate
            86400,          // box 1: 1 day
            86400 * 3,      // box 2: 3 days
            86400 * 7,      // box 3: 7 days
            86400 * 14      // box 4: 14 days
        ]
        let interval = intervals[min(boxLevel, intervals.count - 1)]
        return Date.now.addingTimeInterval(interval)
    }
}

#Preview {
    FlashcardView()
        .modelContainer(for: [WordEntry.self, LanguageConfig.self], inMemory: true)
}
