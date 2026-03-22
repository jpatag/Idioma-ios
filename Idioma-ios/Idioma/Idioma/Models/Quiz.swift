//
//  Quiz.swift
//  Idioma
//
//  Data models for the AI-generated reading comprehension quiz.
//  Matches the JSON schema returned by the generateQuiz backend endpoint.
//

import Foundation

// MARK: - Quiz
/// Top-level response from the generateQuiz endpoint
struct Quiz: Codable {
    let url: String
    let level: String
    let questions: [QuizQuestion]
    let cacheHit: Bool?
}

// MARK: - Quiz Question
/// A single multiple-choice question with 4 options
struct QuizQuestion: Codable, Identifiable {
    var id: Int { questionNumber }
    
    let questionNumber: Int        // 1, 2, or 3
    let questionText: String
    let options: [String]          // exactly 4 options
    let correctAnswerIndex: Int    // 0–3
}
