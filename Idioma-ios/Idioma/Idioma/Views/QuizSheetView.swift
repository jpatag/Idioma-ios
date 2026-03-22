//
//  QuizSheetView.swift
//  Idioma
//
//  Modal sheet for the AI-generated reading comprehension quiz.
//  Presents loading → questions → results flow.
//

import SwiftUI

struct QuizSheetView: View {
    let articleURL: String
    let level: CEFRLevel
    let language: String
    let categories: [Int]
    
    @Environment(\.dismiss) var dismiss
    
    // State
    @State private var quiz: Quiz?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var selectedAnswers: [Int: Int] = [:]  // questionNumber → selected option index
    @State private var isSubmitted: Bool = false
    @State private var loadingMessage: String = "Analyzing vocabulary..."
    
    // Theme
    let primaryColor = Color(red: 236/255, green: 72/255, blue: 153/255)
    
    private let loadingMessages = [
        "Analyzing vocabulary...",
        "Formulating questions...",
        "Reviewing article content...",
        "Building your quiz..."
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error: error)
                } else if let quiz = quiz {
                    if isSubmitted {
                        resultsView(quiz: quiz)
                    } else {
                        questionsView(quiz: quiz)
                    }
                }
            }
            .navigationTitle("Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear { loadQuiz() }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(primaryColor)
            
            Text(loadingMessage)
                .font(.headline)
                .foregroundColor(.secondary)
                .animation(.easeInOut, value: loadingMessage)
        }
        .onAppear { cycleLoadingMessages() }
    }
    
    // MARK: - Error View
    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Couldn't load quiz")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: {
                errorMessage = nil
                loadQuiz()
            }) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 160, height: 44)
                    .background(primaryColor)
                    .cornerRadius(22)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Questions View
    private func questionsView(quiz: Quiz) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(quiz.questions) { question in
                    questionCard(question: question)
                }
                
                // Submit button
                Button(action: { withAnimation { isSubmitted = true } }) {
                    Text("Check Answers")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(allQuestionsAnswered ? primaryColor : Color.gray.opacity(0.4))
                        .cornerRadius(16)
                }
                .disabled(!allQuestionsAnswered)
                .padding(.top, 8)
            }
            .padding(16)
        }
    }
    
    private func questionCard(question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question header
            HStack(spacing: 8) {
                Text("\(question.questionNumber)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(primaryColor)
                    .clipShape(Circle())
                
                Text(questionTypeLabel(for: question.questionNumber))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(question.questionText)
                .font(.body)
                .fontWeight(.medium)
            
            // Options
            VStack(spacing: 8) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    optionButton(
                        text: option,
                        isSelected: selectedAnswers[question.questionNumber] == index,
                        action: {
                            selectedAnswers[question.questionNumber] = index
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
    
    private func optionButton(text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? primaryColor : .secondary.opacity(0.4))
                    .font(.title3)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? primaryColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Results View
    private func resultsView(quiz: Quiz) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Score circle
                let score = calculateScore(quiz: quiz)
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                            .frame(width: 100, height: 100)
                        Circle()
                            .trim(from: 0, to: CGFloat(score) / CGFloat(quiz.questions.count))
                            .stroke(scoreColor(score: score, total: quiz.questions.count), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(score)/\(quiz.questions.count)")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    
                    Text(scoreMessage(score: score, total: quiz.questions.count))
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 16)
                
                // Per-question results
                ForEach(quiz.questions) { question in
                    resultCard(question: question)
                }
                
                // Done button
                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(primaryColor)
                        .cornerRadius(16)
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
    }
    
    private func resultCard(question: QuizQuestion) -> some View {
        let selected = selectedAnswers[question.questionNumber]
        let isCorrect = selected == question.correctAnswerIndex
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isCorrect ? .green : .red)
                    .font(.title3)
                
                Text(question.questionText)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            // Show correct answer if wrong
            if !isCorrect {
                if let selectedIdx = selected, selectedIdx < question.options.count {
                    Text("Your answer: \(question.options[selectedIdx])")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                }
                
                Text("Correct: \(question.options[question.correctAnswerIndex])")
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
    
    // MARK: - Helpers
    
    private var allQuestionsAnswered: Bool {
        guard let quiz = quiz else { return false }
        return quiz.questions.allSatisfy { selectedAnswers[$0.questionNumber] != nil }
    }
    
    private func calculateScore(quiz: Quiz) -> Int {
        quiz.questions.reduce(0) { count, question in
            count + (selectedAnswers[question.questionNumber] == question.correctAnswerIndex ? 1 : 0)
        }
    }
    
    private func scoreColor(score: Int, total: Int) -> Color {
        let ratio = Double(score) / Double(total)
        if ratio >= 0.8 { return .green }
        if ratio >= 0.5 { return .orange }
        return .red
    }
    
    private func scoreMessage(score: Int, total: Int) -> String {
        let ratio = Double(score) / Double(total)
        if ratio >= 1.0 { return "¡Perfecto!" }
        if ratio >= 0.66 { return "¡Muy bien!" }
        if ratio >= 0.33 { return "¡Buen intento!" }
        return "¡Sigue practicando!"
    }
    
    private func questionTypeLabel(for number: Int) -> String {
        switch number {
        case 1: return "Comprehension"
        case 2: return "Vocabulary"
        case 3: return "Inference"
        default: return "Question"
        }
    }
    
    private func cycleLoadingMessages() {
        var index = 0
        Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { timer in
            if !isLoading {
                timer.invalidate()
                return
            }
            index = (index + 1) % loadingMessages.count
            withAnimation {
                loadingMessage = loadingMessages[index]
            }
        }
    }
    
    // MARK: - Load Quiz
    private func loadQuiz() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await APIService.shared.generateQuiz(
                    url: articleURL,
                    level: level,
                    language: language,
                    categories: categories
                )
                
                await MainActor.run {
                    self.quiz = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
