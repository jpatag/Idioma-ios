//
//  SpanishVocabularyHighlighter.swift
//  Idioma
//
//  Loads the bundled Spanish top-1000 vocabulary CSV and highlights
//  category-matched words inside article text.
//

import Foundation
import SwiftUI
import UIKit

struct VocabularyMatch: Equatable {
    let range: NSRange
    let categoryId: Int
}

enum VocabularyLevelID: String, CaseIterable, Hashable {
    case l1 = "L1"
    case l2 = "L2"
    case l3 = "L3"
}

final class SpanishVocabularyHighlighter {
    static let shared = SpanishVocabularyHighlighter()

    static let alwaysOnCategoryIDs: Set<Int> = [15]

    private let queue = DispatchQueue(label: "com.idioma.spanish-vocabulary-highlighter")
    private let tokenRegex = try! NSRegularExpression(pattern: #"\p{L}+(?:[\p{L}\p{M}]*)"#)
    private var cachedWordsByCategoryAndLevel: [Int: [VocabularyLevelID: Set<String>]]?

    private init() {}

    func preload() {
        _ = wordsByCategoryAndLevel()
    }

    func activeCategoryIDs(from articleCategoryIDs: [Int]?) -> Set<Int> {
        var ids = Set(articleCategoryIDs ?? [])
        ids.formUnion(Self.alwaysOnCategoryIDs)
        return ids
    }

    func shouldHighlight(languageCode: String?) -> Bool {
        guard let languageCode else { return false }
        let normalized = languageCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "es" || normalized == "spanish"
    }

    func highlightMatches(in text: String, activeCategoryIDs: Set<Int>, vocabularyLevelIDs: Set<VocabularyLevelID>) -> [VocabularyMatch] {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return [] }

        let start = Date()
        let words = activeWords(for: activeCategoryIDs, vocabularyLevelIDs: vocabularyLevelIDs)
        guard !words.isEmpty else { return [] }

        let nsText = normalizedText as NSString
        let matches = tokenRegex.matches(in: normalizedText, range: NSRange(location: 0, length: nsText.length)).compactMap { result -> VocabularyMatch? in
            let token = nsText.substring(with: result.range)
            let normalizedToken = normalize(token)
            guard !normalizedToken.isEmpty else { return nil }

            for categoryId in activeCategoryIDs.sorted() {
                if words[categoryId]?.contains(normalizedToken) == true {
                    return VocabularyMatch(range: result.range, categoryId: categoryId)
                }
            }

            return nil
        }

        let elapsed = Date().timeIntervalSince(start) * 1000
        let formattedElapsed = String(format: "%.1f", elapsed)
        let levelSummary = vocabularyLevelIDs.map(\.rawValue).sorted().joined(separator: ",")
        print("🟢 [Vocabulary] Matched \(matches.count) levels=[\(levelSummary)] words across \(activeCategoryIDs.sorted()) in \(formattedElapsed) ms")
        return matches
    }

    func makeAttributedString(text: String, activeCategoryIDs: Set<Int>, vocabularyLevelIDs: Set<VocabularyLevelID>) -> AttributedString {
        let matches = highlightMatches(in: text, activeCategoryIDs: activeCategoryIDs, vocabularyLevelIDs: vocabularyLevelIDs)
        return makeAttributedString(text: text, matches: matches)
    }

    func makeAttributedString(text: String, matches: [VocabularyMatch]) -> AttributedString {
        let mutable = NSMutableAttributedString(string: text)

        for match in matches {
            mutable.addAttribute(.backgroundColor, value: highlightColor(for: match.categoryId), range: match.range)
        }

        if let attributed = try? AttributedString(mutable, including: \.uiKit) {
            return attributed
        }

        return AttributedString(text)
    }

    static func plainText(from htmlContent: String) -> String {
        var text = htmlContent
        let replacements: [(String, String)] = [
            ("<[^>]+>", " "),
            ("&nbsp;", " "),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'")
        ]

        for (pattern, replacement) in replacements {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }

        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func activeWords(for activeCategoryIDs: Set<Int>, vocabularyLevelIDs: Set<VocabularyLevelID>) -> [Int: Set<String>] {
        let store = wordsByCategoryAndLevel()
        return activeCategoryIDs.reduce(into: [Int: Set<String>]()) { partialResult, categoryId in
            let mergedWords = vocabularyLevelIDs.reduce(into: Set<String>()) { result, levelID in
                if let words = store[categoryId]?[levelID] {
                    result.formUnion(words)
                }
            }

            if !mergedWords.isEmpty {
                partialResult[categoryId] = mergedWords
            }
        }
    }

    private func wordsByCategoryAndLevel() -> [Int: [VocabularyLevelID: Set<String>]] {
        queue.sync {
            if let cachedWordsByCategoryAndLevel {
                return cachedWordsByCategoryAndLevel
            }

            let start = Date()
            guard let fileURL = Bundle.main.url(forResource: "SpanishTop1000Words", withExtension: "csv") else {
                print("❌ [Vocabulary] Missing bundled resource SpanishTop1000Words.csv")
                cachedWordsByCategoryAndLevel = [:]
                return [:]
            }

            do {
                let raw = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = raw.components(separatedBy: .newlines)
                var store: [Int: [VocabularyLevelID: Set<String>]] = [:]
                var loadedCount = 0

                for line in lines.dropFirst() where !line.isEmpty {
                    let columns = line.split(separator: ",", omittingEmptySubsequences: false)
                    guard columns.count >= 5 else { continue }

                    let word = String(columns[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let categoryId = Int(columns[3]) else { continue }
                    guard let vocabularyLevelID = VocabularyLevelID(rawValue: String(columns[4]).trimmingCharacters(in: .whitespacesAndNewlines)) else {
                        continue
                    }

                    let normalizedWord = normalize(word)
                    guard !normalizedWord.isEmpty else { continue }

                    var categoryStore = store[categoryId, default: [:]]
                    categoryStore[vocabularyLevelID, default: []].insert(normalizedWord)
                    store[categoryId] = categoryStore
                    loadedCount += 1
                }

                let elapsed = Date().timeIntervalSince(start) * 1000
                print("🟢 [Vocabulary] Loaded \(loadedCount) Spanish words across \(store.keys.count) categories in \(String(format: "%.1f", elapsed)) ms")
                cachedWordsByCategoryAndLevel = store
                return store
            } catch {
                print("❌ [Vocabulary] Failed to load SpanishTop1000Words.csv: \(error.localizedDescription)")
                cachedWordsByCategoryAndLevel = [:]
                return [:]
            }
        }
    }

    private func highlightColor(for categoryId: Int) -> UIColor {
        switch categoryId {
        case 15:
            return UIColor.systemGray5
        case 4:
            return UIColor.systemGreen.withAlphaComponent(0.22)
        case 1:
            return UIColor.systemBlue.withAlphaComponent(0.20)
        case 2, 5:
            return UIColor.systemOrange.withAlphaComponent(0.20)
        case 6:
            return UIColor.systemTeal.withAlphaComponent(0.20)
        case 11:
            return UIColor.systemRed.withAlphaComponent(0.18)
        default:
            return UIColor.systemPink.withAlphaComponent(0.18)
        }
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
            .trimmingCharacters(in: .punctuationCharacters.union(.symbols).union(.whitespacesAndNewlines))
            .lowercased()
    }
}
