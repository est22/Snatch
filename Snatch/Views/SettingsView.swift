//
//  SettingsView.swift
//  Snatch
//
//  Configure language pair: mother tongue and learning language.
//  This tells the app which language to treat as "known" vs "learning"
//  when it detects text from clipboard.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [LanguageConfig]

    @State private var motherTongue = "ko"
    @State private var learningLanguage = "en"

    private let supportedLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("ko", "Korean"),
        ("ja", "Japanese"),
        ("zh", "Chinese"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("pt", "Portuguese"),
        ("it", "Italian"),
        ("ru", "Russian"),
        ("ar", "Arabic"),
        ("hi", "Hindi"),
        ("th", "Thai"),
        ("vi", "Vietnamese"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            Form {
                Section("Language Pair") {
                    Picker("Mother Tongue", selection: $motherTongue) {
                        ForEach(supportedLanguages, id: \.code) { lang in
                            Text("\(lang.name) (\(lang.code.uppercased()))").tag(lang.code)
                        }
                    }

                    Picker("Learning Language", selection: $learningLanguage) {
                        ForEach(supportedLanguages, id: \.code) { lang in
                            Text("\(lang.name) (\(lang.code.uppercased()))").tag(lang.code)
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("OCR Engine", value: "Apple Vision (on-device)")
                    LabeledContent("Language Detection", value: "Apple NaturalLanguage (on-device)")
                }
            }
            .formStyle(.grouped)
            .onChange(of: motherTongue) { _, newValue in
                saveConfig()
            }
            .onChange(of: learningLanguage) { _, newValue in
                saveConfig()
            }
        }
        .onAppear {
            if let config = configs.first {
                motherTongue = config.motherTongueCode
                learningLanguage = config.learningLanguageCode
            }
        }
    }

    private func saveConfig() {
        if let config = configs.first {
            config.motherTongueCode = motherTongue
            config.learningLanguageCode = learningLanguage
            config.updatedAt = .now
        } else {
            let config = LanguageConfig(
                motherTongueCode: motherTongue,
                learningLanguageCode: learningLanguage
            )
            modelContext.insert(config)
        }
        try? modelContext.save()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [WordEntry.self, LanguageConfig.self], inMemory: true)
}
