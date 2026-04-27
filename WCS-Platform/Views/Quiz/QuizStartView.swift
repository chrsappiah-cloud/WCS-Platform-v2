//
//  QuizStartView.swift
//  WCS-Platform
//

import SwiftUI

struct QuizStartView: View {
    let quiz: Quiz
    let courseId: UUID
    let moduleId: UUID
    let lessonId: UUID

    @StateObject private var viewModel: QuizViewModel

    init(quiz: Quiz, courseId: UUID, moduleId: UUID, lessonId: UUID) {
        self.quiz = quiz
        self.courseId = courseId
        self.moduleId = moduleId
        self.lessonId = lessonId
        _viewModel = StateObject(wrappedValue: QuizViewModel(quiz: quiz, courseId: courseId, moduleId: moduleId, lessonId: lessonId))
    }

    var body: some View {
        Group {
            if let result = viewModel.result {
                QuizResultView(result: result) {
                    viewModel.resetAttempt()
                }
            } else {
                QuizQuestionView(viewModel: viewModel)
            }
        }
        .navigationTitle(quiz.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct QuizResultView: View {
    let result: QuizSubmissionResult
    let onReset: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(result.isPassed ? "Passed" : "Not passed", systemImage: result.isPassed ? "checkmark.seal.fill" : "xmark.seal.fill")
        } description: {
            VStack(spacing: 8) {
                Text("Score: \(result.score) / \(result.total)")
                Text("Percentage: \(result.percentage, specifier: "%.1f")%")
                Text("Oxford grade: \(result.oxfordGrade.rawValue)")
                    .font(.subheadline.weight(.semibold))
                if let feedback = result.feedback {
                    Text(feedback)
                        .multilineTextAlignment(.center)
                }
                if let cert = result.certification {
                    VStack(spacing: 4) {
                        Text("Certificate issued")
                            .font(.subheadline.weight(.semibold))
                        Text("Verification: \(cert.verificationCode)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } actions: {
            Button("Try again", action: onReset)
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    NavigationStack {
        QuizStartView(
            quiz: MockCourseCatalog.sampleQuiz,
            courseId: UUID(),
            moduleId: UUID(),
            lessonId: UUID()
        )
    }
}
