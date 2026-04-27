//
//  MockCourseCatalog.swift
//  WCS-Platform
//

import Foundation

enum MockCourseCatalog {
    nonisolated static let sampleQuiz = Quiz(
        id: UUID(uuidString: "00000001-0000-0000-0000-000000000001")!,
        title: "Foundations check-in",
        description: "Quick knowledge check.",
        maxAttempts: 3,
        timeLimitSeconds: 300,
        passingScore: 1,
        questions: [
            Question(
                id: UUID(uuidString: "00000002-0000-0000-0000-000000000001")!,
                text: "What is the primary goal of spaced repetition?",
                type: .multipleChoice,
                options: [
                    QuestionOption(id: UUID(), text: "Cramming the night before"),
                    QuestionOption(id: UUID(), text: "Reviewing on expanding intervals"),
                    QuestionOption(id: UUID(), text: "Skipping practice tests"),
                ],
                correctOptionIndex: 1,
                explanation: "Spacing reviews strengthens long-term retention."
            ),
            Question(
                id: UUID(uuidString: "00000002-0000-0000-0000-000000000002")!,
                text: "Active recall is more effective than passive re-reading.",
                type: .trueFalse,
                options: [
                    QuestionOption(id: UUID(), text: "True"),
                    QuestionOption(id: UUID(), text: "False"),
                ],
                correctOptionIndex: 0,
                explanation: nil
            ),
        ]
    )

    nonisolated static let sampleAssignment = Assignment(
        id: UUID(uuidString: "00000003-0000-0000-0000-000000000001")!,
        title: "Reflection: your learning plan",
        description: "Write 200–400 words on how you will apply this week’s concepts.",
        dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
        maxAttempts: 1,
        isSubmitted: false,
        submission: nil
    )

    nonisolated static let courses: [Course] = {
        let courseIdA = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let moduleIdA = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let lessonVideo = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let lessonReading = UUID(uuidString: "30000000-0000-0000-0000-000000000002")!
        let lessonQuiz = UUID(uuidString: "30000000-0000-0000-0000-000000000003")!
        let lessonAssignment = UUID(uuidString: "30000000-0000-0000-0000-000000000004")!

        let moduleA = Module(
            id: moduleIdA,
            title: "Week 1 — Foundations",
            description: "Orientation, study design, and practice.",
            order: 1,
            isAvailable: true,
            isUnlocked: true,
            lessons: [
                Lesson(
                    id: lessonVideo,
                    title: "How high performers study",
                    subtitle: "Video · 10 min",
                    type: .video,
                    videoURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8",
                    durationSeconds: 596,
                    isCompleted: false,
                    isAvailable: true,
                    isUnlocked: true,
                    reading: nil,
                    quiz: nil,
                    assignment: nil
                ),
                Lesson(
                    id: lessonReading,
                    title: "Course handbook",
                    subtitle: "Reading · 5 min",
                    type: .reading,
                    videoURL: nil,
                    durationSeconds: 12,
                    isCompleted: false,
                    isAvailable: true,
                    isUnlocked: true,
                    reading: ReadingContent(markdown: "## Welcome\n\nTrack progress from the **Programs** tab. Complete each unit in order—quizzes grade instantly in mock mode.\n\n### What you’ll build\n- Focus habits\n- Retrieval practice\n- Self-paced mastery"),
                    quiz: nil,
                    assignment: nil
                ),
                Lesson(
                    id: lessonQuiz,
                    title: "Week 1 quiz",
                    subtitle: "Graded assessment",
                    type: .quiz,
                    videoURL: nil,
                    durationSeconds: 10,
                    isCompleted: false,
                    isAvailable: true,
                    isUnlocked: true,
                    reading: nil,
                    quiz: sampleQuiz,
                    assignment: nil
                ),
                Lesson(
                    id: lessonAssignment,
                    title: "Apply it",
                    subtitle: "Instructor graded",
                    type: .assignment,
                    videoURL: nil,
                    durationSeconds: 45,
                    isCompleted: false,
                    isAvailable: true,
                    isUnlocked: true,
                    reading: nil,
                    quiz: nil,
                    assignment: sampleAssignment
                ),
            ]
        )

        let courseIdB = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        let moduleIdB = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        let lessonB1 = UUID(uuidString: "30000000-0000-0000-0000-000000000010")!
        let lessonB2 = UUID(uuidString: "30000000-0000-0000-0000-000000000011")!

        let moduleB = Module(
            id: moduleIdB,
            title: "Module 1 — Decisions under uncertainty",
            description: "Framing problems and communicating insights.",
            order: 1,
            isAvailable: true,
            isUnlocked: true,
            lessons: [
                Lesson(
                    id: lessonB1,
                    title: "From data to decision",
                    subtitle: "Video · 8 min",
                    type: .video,
                    videoURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8",
                    durationSeconds: 15,
                    isCompleted: false,
                    isAvailable: true,
                    isUnlocked: true,
                    reading: nil,
                    quiz: nil,
                    assignment: nil
                ),
                Lesson(
                    id: lessonB2,
                    title: "Knowledge check",
                    subtitle: "Practice quiz",
                    type: .quiz,
                    videoURL: nil,
                    durationSeconds: 5,
                    isCompleted: false,
                    isAvailable: true,
                    isUnlocked: true,
                    reading: nil,
                    quiz: Quiz(
                        id: UUID(uuidString: "00000001-0000-0000-0000-000000000099")!,
                        title: "Quick check",
                        description: nil,
                        maxAttempts: 5,
                        timeLimitSeconds: 120,
                        passingScore: 1,
                        questions: [
                            Question(
                                id: UUID(),
                                text: "A confidence interval communicates uncertainty about a parameter estimate.",
                                type: .trueFalse,
                                options: [
                                    QuestionOption(id: UUID(), text: "True"),
                                    QuestionOption(id: UUID(), text: "False"),
                                ],
                                correctOptionIndex: 0,
                                explanation: nil
                            ),
                        ]
                    ),
                    assignment: nil
                ),
            ]
        )

        let courseIdC = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
        let moduleIdC = UUID(uuidString: "20000000-0000-0000-0000-000000000003")!
        let lessonC1 = UUID(uuidString: "30000000-0000-0000-0000-000000000021")!
        let lessonC2 = UUID(uuidString: "30000000-0000-0000-0000-000000000022")!
        let lessonC3 = UUID(uuidString: "30000000-0000-0000-0000-000000000023")!
        let lessonC4 = UUID(uuidString: "30000000-0000-0000-0000-000000000024")!

        let moduleC = Module(
            id: moduleIdC,
            title: "Module 1 - Humane and trauma-aware care systems",
            description: "Disability, mental health, and dementia care grounded in social justice.",
            order: 1,
            isAvailable: true,
            isUnlocked: true,
            lessons: [
                Lesson(
                    id: lessonC1,
                    title: "Social justice foundations in care",
                    subtitle: "Video + companion curation",
                    type: .video,
                    videoURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8",
                    durationSeconds: 780,
                    isCompleted: false,
                    isAvailable: true,
                    isUnlocked: true,
                    reading: nil,
                    quiz: nil,
                    assignment: nil
                ),
                Lesson(
                    id: lessonC2,
                    title: "Profile-linked media and references",
                    subtitle: "Reading + YouTube companions",
                    type: .reading,
                    videoURL: nil,
                    durationSeconds: 360,
                    isCompleted: false,
                    isAvailable: true,
                    isUnlocked: true,
                    reading: ReadingContent(markdown: """
                    ## Curated from Dr Christopher Appiah-Thompson public profile

                    ### Public links and channels
                    - Professional hub: [christopherappiahthompson.link](https://christopherappiahthompson.link)
                    - Podcast feature: [Introducing Truth and Light](https://rss.com/podcasts/heartbeats-beyond-memory-creative-care-in-dementia/2357430)
                    - African history project: [African history and its discontents](https://africanhistoryanditsdiscontentsafricanhistoryanditsdiscontents.codeadx.me/)
                    - WCS Future Lab: [myworldclass.net](https://myworldclass.net/)
                    - WCS Art Verse: [wcs-art-verse.com](https://wcs-art-verse.com/)
                    - WCS Future Lab Gallery: [wcsflab.com](https://www.wcsflab.com/)

                    ### Verified account categories
                    - LinkedIn
                    - TikTok
                    - Facebook
                    - YouTube

                    ### Suggested YouTube companions for this module
                    - [Trauma informed care essentials](https://www.youtube.com/results?search_query=trauma+informed+care+essentials)
                    - [Dementia person centred communication](https://www.youtube.com/results?search_query=dementia+person+centred+communication)
                    - [Mental health advocacy policy design](https://www.youtube.com/results?search_query=mental+health+advocacy+policy+design)
                    """),
                    quiz: nil,
                    assignment: nil
                ),
                Lesson(
                    id: lessonC3,
                    title: "Ethical service design quiz",
                    subtitle: "Knowledge check",
                    type: .quiz,
                    videoURL: nil,
                    durationSeconds: 240,
                    isCompleted: false,
                    isAvailable: true,
                    isUnlocked: true,
                    reading: nil,
                    quiz: Quiz(
                        id: UUID(uuidString: "00000001-0000-0000-0000-000000000120")!,
                        title: "Humane care systems quiz",
                        description: "Assess applied understanding of dignity-first service design.",
                        maxAttempts: 3,
                        timeLimitSeconds: 600,
                        passingScore: 2,
                        questions: [
                            Question(
                                id: UUID(),
                                text: "Trauma-aware communication should prioritize safety, choice, and trust.",
                                type: .trueFalse,
                                options: [
                                    QuestionOption(id: UUID(), text: "True"),
                                    QuestionOption(id: UUID(), text: "False"),
                                ],
                                correctOptionIndex: 0,
                                explanation: "These are core trauma-informed care principles."
                            ),
                            Question(
                                id: UUID(),
                                text: "Which is the strongest lived-experience practice?",
                                type: .multipleChoice,
                                options: [
                                    QuestionOption(id: UUID(), text: "Design policy without user input"),
                                    QuestionOption(id: UUID(), text: "Co-design services with affected communities"),
                                    QuestionOption(id: UUID(), text: "Use one-size-fits-all communication"),
                                ],
                                correctOptionIndex: 1,
                                explanation: "Co-design improves dignity, relevance, and outcomes."
                            ),
                        ]
                    ),
                    assignment: nil
                ),
                Lesson(
                    id: lessonC4,
                    title: "Care pathway redesign brief",
                    subtitle: "Applied assignment",
                    type: .assignment,
                    videoURL: nil,
                    durationSeconds: 900,
                    isCompleted: false,
                    isAvailable: true,
                    isUnlocked: true,
                    reading: nil,
                    quiz: nil,
                    assignment: Assignment(
                        id: UUID(uuidString: "00000003-0000-0000-0000-000000000120")!,
                        title: "Redesign a trauma-aware pathway",
                        description: "Draft a 1-page service improvement brief covering language standards, escalation, and lived-experience checkpoints.",
                        dueDate: Calendar.current.date(byAdding: .day, value: 10, to: Date()),
                        maxAttempts: 1,
                        isSubmitted: false,
                        submission: nil
                    )
                ),
            ]
        )

        let courseIdD = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
        let moduleIdD = UUID(uuidString: "20000000-0000-0000-0000-000000000004")!
        let lessonD1 = UUID(uuidString: "30000000-0000-0000-0000-000000000031")!
        let lessonD2 = UUID(uuidString: "30000000-0000-0000-0000-000000000032")!
        let lessonD3 = UUID(uuidString: "30000000-0000-0000-0000-000000000033")!

        let moduleD = Module(
            id: moduleIdD,
            title: "Module 1 - Ethical digital campaigns and storytelling",
            description: "Campaign strategy, media narrative, and brand integrity for purpose-driven organisations.",
            order: 1,
            isAvailable: true,
            isUnlocked: true,
            lessons: [
                Lesson(
                    id: lessonD1,
                    title: "Digital campaign architecture",
                    subtitle: "Video workshop",
                    type: .video,
                    videoURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8",
                    durationSeconds: 840,
                    isCompleted: false,
                    isAvailable: true,
                    isUnlocked: true,
                    reading: nil,
                    quiz: nil,
                    assignment: nil
                ),
                Lesson(
                    id: lessonD2,
                    title: "YouTube and social distribution stack",
                    subtitle: "Reading + content pack",
                    type: .reading,
                    videoURL: nil,
                    durationSeconds: 300,
                    isCompleted: false,
                    isAvailable: true,
                    isUnlocked: true,
                    reading: ReadingContent(markdown: """
                    ## Distribution stack for World Class Scholars campaigns

                    - Primary profile and links: [christopherappiahthompson.link](https://christopherappiahthompson.link)
                    - Verified account channels: LinkedIn, TikTok, Facebook, YouTube
                    - Gallery amplification: [WCS Art Verse](https://wcs-art-verse.com/) and [WCS Future Lab](https://www.wcsflab.com/)

                    ### Recommended YouTube discovery queues
                    - [Social justice communication strategy](https://www.youtube.com/results?search_query=social+justice+communication+strategy)
                    - [Dementia care storytelling campaign](https://www.youtube.com/results?search_query=dementia+care+storytelling+campaign)
                    - [Ethical nonprofit digital marketing](https://www.youtube.com/results?search_query=ethical+nonprofit+digital+marketing)
                    """),
                    quiz: nil,
                    assignment: nil
                ),
                Lesson(
                    id: lessonD3,
                    title: "Campaign sprint assignment",
                    subtitle: "Project submission",
                    type: .assignment,
                    videoURL: nil,
                    durationSeconds: 1200,
                    isCompleted: false,
                    isAvailable: true,
                    isUnlocked: true,
                    reading: nil,
                    quiz: nil,
                    assignment: Assignment(
                        id: UUID(uuidString: "00000003-0000-0000-0000-000000000130")!,
                        title: "Build a 14-day campaign sprint",
                        description: "Submit a campaign plan including audience, message pillars, 3 YouTube concepts, and accessibility checks.",
                        dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()),
                        maxAttempts: 1,
                        isSubmitted: false,
                        submission: nil
                    )
                ),
            ]
        )

        return [
            Course(
                id: courseIdA,
                title: "Learning How to Learn",
                subtitle: "Evidence-based study skills",
                description: "Build durable memory, manage procrastination, and design practice like top open-course programs: structured modules, clear outcomes, graded checks, and authentic assignments.",
                thumbnailURL: "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=1200&q=80",
                coverURL: "https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=1600&q=80",
                durationSeconds: 3600,
                price: 49.99,
                isEnrolled: false,
                isOwned: false,
                isUnlockedBySubscription: true,
                rating: 4.8,
                reviewCount: 1284,
                organizationName: "World Class Scholars",
                level: "Introductory",
                effortDescription: "2–4 hrs/week",
                spokenLanguages: ["English"],
                modules: [moduleA]
            ),
            Course(
                id: courseIdB,
                title: "Decision Science Essentials",
                subtitle: "Think clearly with data",
                description: "A compact program on framing decisions, interpreting evidence, and communicating tradeoffs—mirroring the syllabus + assessment cadence of flagship online programs.",
                thumbnailURL: "https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=1200&q=80",
                coverURL: "https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=1600&q=80",
                durationSeconds: 2100,
                price: nil,
                isEnrolled: false,
                isOwned: false,
                isUnlockedBySubscription: true,
                rating: 4.6,
                reviewCount: 612,
                organizationName: "WCS Analytics Studio",
                level: "Intermediate",
                effortDescription: "3–5 hrs/week",
                spokenLanguages: ["English"],
                modules: [moduleB]
            ),
            Course(
                id: courseIdC,
                title: "Social Justice in Disability, Mental Health and Dementia Care",
                subtitle: "Policy, advocacy, and humane service design",
                description: "Built from Dr Christopher Appiah-Thompson public profile themes: social justice, trauma-aware communication, and inclusive co-design for real-world care systems.",
                thumbnailURL: "https://images.unsplash.com/photo-1450101499163-c8848c66ca85?w=1200&q=80",
                coverURL: "https://images.unsplash.com/photo-1526256262350-7da7584cf5eb?w=1600&q=80",
                durationSeconds: 4200,
                price: nil,
                isEnrolled: false,
                isOwned: false,
                isUnlockedBySubscription: true,
                rating: 4.9,
                reviewCount: 214,
                organizationName: "World Class Scholars",
                level: "Advanced",
                effortDescription: "4–6 hrs/week",
                spokenLanguages: ["English"],
                modules: [moduleC]
            ),
            Course(
                id: courseIdD,
                title: "Ethical Digital Campaigns for Care and Community Services",
                subtitle: "Storytelling, advocacy, and social media systems",
                description: "A platform-ready campaign program aligned to verified channels and public portfolio content, with YouTube companion queues and practical project delivery.",
                thumbnailURL: "https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=1200&q=80",
                coverURL: "https://images.unsplash.com/photo-1494172961521-33799ddd43a5?w=1600&q=80",
                durationSeconds: 3600,
                price: 79.99,
                isEnrolled: false,
                isOwned: false,
                isUnlockedBySubscription: true,
                rating: 4.8,
                reviewCount: 127,
                organizationName: "WCS Media Lab",
                level: "Intermediate",
                effortDescription: "3–5 hrs/week",
                spokenLanguages: ["English"],
                modules: [moduleD]
            ),
        ]
    }()

    static func displayTitle(for courseId: UUID) -> String {
        courses.first { $0.id == courseId }?.title ?? "Continue program"
    }

    static func thumbnailURL(for courseId: UUID) -> URL? {
        guard let raw = courses.first(where: { $0.id == courseId })?.thumbnailURL else { return nil }
        return URL(string: raw)
    }

    static func findQuiz(id: UUID) -> Quiz? {
        for course in courses {
            for module in course.modules {
                for lesson in module.lessons {
                    if let quiz = lesson.quiz, quiz.id == id {
                        return quiz
                    }
                }
            }
        }
        return nil
    }

    struct QuizLocation: Sendable, Hashable {
        let courseId: UUID
        let moduleId: UUID
        let lessonId: UUID
    }

    static func findQuizLocation(id: UUID) -> QuizLocation? {
        for course in courses {
            for module in course.modules {
                for lesson in module.lessons {
                    if let quiz = lesson.quiz, quiz.id == id {
                        return QuizLocation(courseId: course.id, moduleId: module.id, lessonId: lesson.id)
                    }
                }
            }
        }
        return nil
    }
}
