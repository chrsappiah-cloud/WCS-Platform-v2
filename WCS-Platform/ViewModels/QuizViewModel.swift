//
//  QuizViewModel.swift
//  WCS-Platform
//

import Combine
import Foundation

@MainActor
final class QuizViewModel: ObservableObject {
    @Published private(set) var quiz: Quiz
    private let courseId: UUID?
    private let moduleId: UUID?
    private let lessonId: UUID?
    @Published var currentIndex: Int = 0
    @Published var selections: [UUID: Int] = [:]
    @Published var isSubmitting = false
    @Published var result: QuizSubmissionResult?
    @Published var lastError: WCSAPIError?
    private let learningRepository: LearningRepository

    var currentQuestion: Question? {
        guard quiz.questions.indices.contains(currentIndex) else { return nil }
        return quiz.questions[currentIndex]
    }

    init(
        quiz: Quiz,
        courseId: UUID? = nil,
        moduleId: UUID? = nil,
        lessonId: UUID? = nil,
        learningRepository: LearningRepository = WCSAppContainer.shared.learning
    ) {
        self.quiz = quiz
        self.courseId = courseId
        self.moduleId = moduleId
        self.lessonId = lessonId
        self.learningRepository = learningRepository
    }

    func selectOption(index: Int) {
        guard let q = currentQuestion else { return }
        selections[q.id] = index
    }

    func next() {
        guard currentIndex + 1 < quiz.questions.count else { return }
        currentIndex += 1
    }

    func previous() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    func submit() async {
        isSubmitting = true
        lastError = nil
        defer { isSubmitting = false }
        do {
            result = try await learningRepository.submitQuiz(
                quizId: quiz.id,
                answers: selections,
                courseId: courseId,
                moduleId: moduleId,
                lessonId: lessonId
            )
        } catch let api as WCSAPIError {
            lastError = api
        } catch {
            lastError = WCSAPIError(underlying: error, statusCode: nil, body: nil)
        }
    }

    func resetAttempt() {
        result = nil
        currentIndex = 0
        selections = [:]
        lastError = nil
    }
}
