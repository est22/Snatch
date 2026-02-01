//
//  WordListView.swift
//  Snatch
//
//  Displays all saved vocabulary entries, organized by language.
//  This view is LAZY-LOADED - it only initializes when the user
//  taps the "Words" tab. The home screen stays fast.
//
//  Features:
//  - Filter by language (learning vs native)
//  - Search through saved words
//  - Favorite words for quick access
//  - Delete words with swipe
//

import SwiftUI
import SwiftData

struct WordListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WordEntry.createdAt, order: .reverse) private var allEntries: [WordEntry]

    @State private var searchText = ""
    @State private var filterLanguage: String? = nil
    @State private var showFavoritesOnly = false

    private var filteredEntries: [WordEntry] {
        allEntries.filter { entry in
            if showFavoritesOnly && !entry.isFavorite { return false }
            if let lang = filterLanguage, entry.languageCode != lang { return false }
            if !searchText.isEmpty {
                return entry.word.localizedCaseInsensitiveContains(searchText)
                    || entry.exampleSentence.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }
    }

    private var availableLanguages: [String] {
        Array(Set(allEntries.map(\.languageCode))).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Word List")
                    .font(.headline)

                Spacer()

                // Filter controls
                Picker("Language", selection: $filterLanguage) {
                    Text("All").tag(nil as String?)
                    ForEach(availableLanguages, id: \.self) { lang in
                        Text(lang.uppercased()).tag(lang as String?)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)

                Toggle(isOn: $showFavoritesOnly) {
                    Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                }
                .toggleStyle(.button)
            }
            .padding()

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search words...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.textBackgroundColor).opacity(0.5))

            Divider()

            // Word list
            if filteredEntries.isEmpty {
                VStack {
                    Spacer()
                    if allEntries.isEmpty {
                        Text("No words saved yet")
                            .foregroundStyle(.secondary)
                        Text("Paste text or a screenshot on the Home tab")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("No matches")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        WordRow(entry: entry)
                    }
                    .onDelete(perform: deleteEntries)
                }
                .listStyle(.inset)
            }
        }
        .searchable(text: $searchText, prompt: "Search words")
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredEntries[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Word Row

private struct WordRow: View {
    @Bindable var entry: WordEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.word)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(entry.languageCode.uppercased())
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue.opacity(0.1)))
                }

                if !entry.exampleSentence.isEmpty && entry.exampleSentence != entry.word {
                    Text(entry.exampleSentence)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(entry.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Leitner box indicator
            HStack(spacing: 2) {
                ForEach(0..<5) { level in
                    Circle()
                        .fill(level <= entry.boxLevel ? Color.green : Color.gray.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
            }

            Button {
                entry.isFavorite.toggle()
                try? entry.modelContext?.save()
            } label: {
                Image(systemName: entry.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(entry.isFavorite ? .yellow : .gray)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WordListView()
        .modelContainer(for: [WordEntry.self, LanguageConfig.self], inMemory: true)
}
