//
//  KokoroTextChunker.swift
//  InsightAtlas
//
//  Sentence-aware text chunking for bounded offline synthesis calls.
//

import Foundation

struct KokoroTextChunker: Sendable {
    let maximumCharacters: Int

    init(maximumCharacters: Int = 1_500) {
        self.maximumCharacters = max(1, maximumCharacters)
    }

    func chunks(for text: String) -> [String] {
        let normalized = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard !normalized.isEmpty else { return [] }

        let sentences = sentenceSegments(from: normalized)
        var result: [String] = []
        var current = ""

        for sentence in sentences {
            if sentence.count > maximumCharacters {
                flush(&current, into: &result)
                result.append(contentsOf: splitOversizedSegment(sentence))
                continue
            }

            let candidate = current.isEmpty ? sentence : "\(current) \(sentence)"
            if candidate.count <= maximumCharacters {
                current = candidate
            } else {
                flush(&current, into: &result)
                current = sentence
            }
        }

        flush(&current, into: &result)
        return result
    }

    private func sentenceSegments(from text: String) -> [String] {
        var sentences: [String] = []
        var words: [Substring] = []

        for word in text.split(separator: " ") {
            words.append(word)
            if let last = word.last, ".!?".contains(last) {
                sentences.append(words.joined(separator: " "))
                words.removeAll(keepingCapacity: true)
            }
        }

        if !words.isEmpty {
            sentences.append(words.joined(separator: " "))
        }
        return sentences
    }

    private func splitOversizedSegment(_ segment: String) -> [String] {
        var chunks: [String] = []
        var current = ""

        for word in segment.split(separator: " ").map(String.init) {
            if word.count > maximumCharacters {
                flush(&current, into: &chunks)
                chunks.append(contentsOf: splitOversizedWord(word))
                continue
            }

            let candidate = current.isEmpty ? word : "\(current) \(word)"
            if candidate.count <= maximumCharacters {
                current = candidate
            } else {
                flush(&current, into: &chunks)
                current = word
            }
        }

        flush(&current, into: &chunks)
        return chunks
    }

    private func splitOversizedWord(_ word: String) -> [String] {
        var pieces: [String] = []
        var start = word.startIndex

        while start < word.endIndex {
            let end = word.index(
                start,
                offsetBy: maximumCharacters,
                limitedBy: word.endIndex
            ) ?? word.endIndex
            pieces.append(String(word[start..<end]))
            start = end
        }
        return pieces
    }

    private func flush(_ current: inout String, into chunks: inout [String]) {
        guard !current.isEmpty else { return }
        chunks.append(current)
        current = ""
    }
}
