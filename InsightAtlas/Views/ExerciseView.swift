import SwiftUI

/// Premium view for displaying various exercise types with iOS/iPadOS optimization
/// Follows AnalysisTheme design system with burnt orange brand colors
struct ExerciseView: View {

    let exercise: any Exercise
    
    // MARK: - iPad Optimization
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private var contentPadding: CGFloat {
        isIPad ? AnalysisTheme.Spacing.xl2 : AnalysisTheme.Spacing.xl
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.lg) {
            // Header
            exerciseHeader

            Divider()
                .background(AnalysisTheme.borderMedium)

            // Content based on exercise type
            exerciseContent
        }
        .padding(contentPadding)
        .background(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.xl)
                .fill(AnalysisTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.xl)
                .stroke(exerciseColor.opacity(0.2), lineWidth: 2)
        )
        .shadow(color: AnalysisTheme.shadowCard, radius: 12, x: 0, y: 4)
        .overlay(alignment: .top) {
            // Premium accent stripe
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [exerciseColor.opacity(0.8), exerciseColor, exerciseColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)
                .clipShape(
                    RoundedCorner(radius: AnalysisTheme.Radius.xl, corners: [.topLeft, .topRight])
                )
        }
    }

    private var exerciseHeader: some View {
        HStack(alignment: .top, spacing: AnalysisTheme.Spacing.md) {
            // Icon with premium styling
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [exerciseColor.opacity(0.15), exerciseColor.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isIPad ? 56 : 48, height: isIPad ? 56 : 48)
                
                Image(systemName: exerciseIcon)
                    .font(.system(size: isIPad ? 24 : 20, weight: .semibold))
                    .foregroundStyle(exerciseColor)
            }

            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.xs) {
                // Exercise type label
                Text(exerciseTypeLabel)
                    .font(isIPad ? .system(size: 11, weight: .bold, design: .rounded) : .analysisUISmall())
                    .fontWeight(.bold)
                    .tracking(1.2)
                    .foregroundStyle(exerciseColor)

                // Exercise title
                Text(exercise.title)
                    .font(isIPad ? .analysisDisplayH3() : .analysisDisplayH4())
                    .foregroundColor(AnalysisTheme.textHeading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AnalysisTheme.Spacing.sm)

            // Time badge
            if let time = exercise.estimatedTime {
                VStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(exerciseColor)
                    
                    Text(time)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(AnalysisTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md)
                        .fill(exerciseColor.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md)
                        .stroke(exerciseColor.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    @ViewBuilder
    private var exerciseContent: some View {
        if let reflection = exercise as? ReflectionExercise {
            reflectionContent(reflection)
        } else if let assessment = exercise as? SelfAssessmentExercise {
            assessmentContent(assessment)
        } else if let scenario = exercise as? ScenarioExercise {
            scenarioContent(scenario)
        } else if let tracking = exercise as? TrackingExercise {
            trackingContent(tracking)
        } else if let dialogue = exercise as? DialogueExercise {
            dialogueContent(dialogue)
        } else if let interrupt = exercise as? PatternInterruptExercise {
            patternInterruptContent(interrupt)
        }
    }

    // MARK: - Exercise Type Helpers

    private var exerciseIcon: String {
        if exercise is ReflectionExercise { return "pencil.and.outline" }
        if exercise is SelfAssessmentExercise { return "chart.bar.fill" }
        if exercise is ScenarioExercise { return "questionmark.bubble.fill" }
        if exercise is TrackingExercise { return "calendar.badge.checkmark" }
        if exercise is DialogueExercise { return "bubble.left.and.bubble.right.fill" }
        if exercise is PatternInterruptExercise { return "hand.raised.slash.fill" }
        return "doc.text.fill"
    }

    private var exerciseColor: Color {
        // Using brand color palette
        if exercise is ReflectionExercise { return AnalysisTheme.accentTeal } // Steel Blue for introspection
        if exercise is SelfAssessmentExercise { return AnalysisTheme.primaryGold } // Burnt Orange for evaluation
        if exercise is ScenarioExercise { return AnalysisTheme.accentSuccess } // Sage Green for practice
        if exercise is TrackingExercise { return AnalysisTheme.accentBurgundy } // Burgundy for tracking
        if exercise is DialogueExercise { return AnalysisTheme.accentTeal } // Steel Blue for communication
        if exercise is PatternInterruptExercise { return AnalysisTheme.primaryGold } // Burnt Orange for action
        return AnalysisTheme.textMuted
    }

    private var exerciseTypeLabel: String {
        if exercise is ReflectionExercise { return "REFLECTION" }
        if exercise is SelfAssessmentExercise { return "SELF-ASSESSMENT" }
        if exercise is ScenarioExercise { return "SCENARIO" }
        if exercise is TrackingExercise { return "TRACKING" }
        if exercise is DialogueExercise { return "DIALOGUE" }
        if exercise is PatternInterruptExercise { return "PATTERN INTERRUPT" }
        return "EXERCISE"
    }

    // MARK: - Content Views

    private func reflectionContent(_ exercise: ReflectionExercise) -> some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.lg) {
            // Prompt
            Text(exercise.prompt)
                .font(isIPad ? .analysisBodyLarge() : .analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
                .italic()
                .padding(AnalysisTheme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                        .fill(exerciseColor.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                        .strokeBorder(exerciseColor.opacity(0.2), lineWidth: 1)
                )

            // Writing area prompt
            HStack(spacing: AnalysisTheme.Spacing.md) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18))
                    .foregroundStyle(exerciseColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reflection Space")
                        .font(.analysisUIBold())
                        .foregroundColor(AnalysisTheme.textHeading)
                    
                    Text("Use a journal or note-taking app to write your reflection")
                        .font(.analysisUISmall())
                        .foregroundColor(AnalysisTheme.textMuted)
                }
            }
            .padding(AnalysisTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AnalysisTheme.bgSecondary)
            .cornerRadius(AnalysisTheme.Radius.md)
        }
    }

    private func assessmentContent(_ exercise: SelfAssessmentExercise) -> some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.lg) {
            // Instructions
            Text("Rate yourself 1-\(exercise.dimensions.first?.maxScore ?? 10) on each dimension:")
                .font(.analysisBody())
                .foregroundStyle(AnalysisTheme.textMuted)

            // Dimensions
            VStack(spacing: AnalysisTheme.Spacing.md) {
                ForEach(exercise.dimensions) { dimension in
                    HStack(spacing: AnalysisTheme.Spacing.md) {
                        // Dimension name
                        Text(dimension.name)
                            .font(isIPad ? .analysisBodyLarge() : .analysisBody())
                            .foregroundColor(AnalysisTheme.textBody)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Score field with premium styling
                        HStack(spacing: 4) {
                            Text("___")
                                .font(.system(size: isIPad ? 20 : 17, weight: .medium, design: .monospaced))
                                .foregroundColor(exerciseColor)
                            
                            Text("/")
                                .font(.system(size: isIPad ? 16 : 14))
                                .foregroundColor(AnalysisTheme.textMuted)
                            
                            Text("\(dimension.maxScore)")
                                .font(.system(size: isIPad ? 16 : 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(AnalysisTheme.textMuted)
                        }
                        .padding(.horizontal, AnalysisTheme.Spacing.md)
                        .padding(.vertical, AnalysisTheme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md)
                                .fill(exerciseColor.opacity(0.08))
                        )
                    }
                    .padding(AnalysisTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                            .fill(AnalysisTheme.bgCard)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                            .stroke(AnalysisTheme.borderLight, lineWidth: 1)
                    )
                }
            }

            Divider()
                .background(AnalysisTheme.borderMedium)

            // Scoring Interpretation
            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.system(size: 14))
                        .foregroundColor(exerciseColor)
                    
                    Text("Scoring Interpretation")
                        .font(.analysisUIBold())
                        .foregroundColor(AnalysisTheme.textHeading)
                }

                Text(exercise.scoringInterpretation)
                    .font(.analysisBody())
                    .foregroundColor(AnalysisTheme.textMuted)
                    .padding(AnalysisTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AnalysisTheme.bgSecondary)
                    .cornerRadius(AnalysisTheme.Radius.md)
            }
        }
    }

    private func scenarioContent(_ exercise: ScenarioExercise) -> some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.xl) {
            // Scenario
            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.image.fill")
                        .font(.system(size: 14))
                        .foregroundColor(exerciseColor)
                    
                    Text("SCENARIO")
                        .font(.analysisUIBold())
                        .foregroundColor(exerciseColor)
                        .tracking(1)
                }

                Text(exercise.scenario)
                    .font(isIPad ? .analysisBodyLarge() : .analysisBody())
                    .foregroundColor(AnalysisTheme.textBody)
                    .padding(AnalysisTheme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [
                                AnalysisTheme.bgSecondary,
                                AnalysisTheme.brandParchment
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(AnalysisTheme.Radius.lg)
                    .overlay(
                        RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                            .stroke(exerciseColor.opacity(0.15), lineWidth: 1)
                    )
            }

            // Question
            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(exerciseColor)
                    
                    Text("QUESTION")
                        .font(.analysisUIBold())
                        .foregroundColor(exerciseColor)
                        .tracking(1)
                }

                Text(exercise.question)
                    .font(isIPad ? .analysisBodyLarge() : .analysisBody())
                    .fontWeight(.medium)
                    .foregroundColor(AnalysisTheme.textHeading)
            }

            // Considerations
            if !exercise.considerations.isEmpty {
                VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AnalysisTheme.textMuted)
                        
                        Text("Consider:")
                            .font(.analysisUIBold())
                            .foregroundColor(AnalysisTheme.textMuted)
                    }

                    VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                        ForEach(exercise.considerations, id: \.self) { consideration in
                            HStack(alignment: .top, spacing: AnalysisTheme.Spacing.md) {
                                Circle()
                                    .fill(exerciseColor.opacity(0.6))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 8)
                                
                                Text(consideration)
                                    .font(.analysisBody())
                                    .foregroundColor(AnalysisTheme.textBody)
                            }
                        }
                    }
                    .padding(AnalysisTheme.Spacing.md)
                    .background(exerciseColor.opacity(0.05))
                    .cornerRadius(AnalysisTheme.Radius.md)
                }
            }
        }
    }

    private func trackingContent(_ exercise: TrackingExercise) -> some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.lg) {
            // Instructions with icon
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 14))
                    .foregroundColor(exerciseColor)
                
                Text("WEEKLY TRACKER")
                    .font(.analysisUIBold())
                    .foregroundColor(exerciseColor)
                    .tracking(1)
            }
            
            // Responsive table layout
            if isIPad {
                desktopTrackingTable(exercise)
            } else {
                mobileTrackingCards(exercise)
            }

            Divider()
                .background(AnalysisTheme.borderMedium)

            // Reflection questions
            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(exerciseColor)
                    
                    Text("End-of-Week Reflection")
                        .font(.analysisUIBold())
                        .foregroundColor(AnalysisTheme.textHeading)
                }

                VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                    ForEach(exercise.reflectionQuestions, id: \.self) { question in
                        HStack(alignment: .top, spacing: AnalysisTheme.Spacing.md) {
                            Circle()
                                .fill(exerciseColor.opacity(0.6))
                                .frame(width: 6, height: 6)
                                .padding(.top, 8)
                            
                            Text(question)
                                .font(.analysisBody())
                                .foregroundColor(AnalysisTheme.textBody)
                        }
                    }
                }
                .padding(AnalysisTheme.Spacing.md)
                .background(AnalysisTheme.bgSecondary)
                .cornerRadius(AnalysisTheme.Radius.md)
            }
        }
    }
    
    // Desktop/iPad tracking table
    private func desktopTrackingTable(_ exercise: TrackingExercise) -> some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("Day")
                    .font(.analysisUIBold())
                    .foregroundColor(AnalysisTheme.textHeading)
                    .frame(width: 60, alignment: .leading)
                    .padding(.horizontal, AnalysisTheme.Spacing.md)
                    .padding(.vertical, AnalysisTheme.Spacing.sm)
                
                ForEach(exercise.columns, id: \.self) { column in
                    Text(column)
                        .font(.analysisUIBold())
                        .foregroundColor(AnalysisTheme.textHeading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AnalysisTheme.Spacing.md)
                        .padding(.vertical, AnalysisTheme.Spacing.sm)
                }
            }
            .background(exerciseColor.opacity(0.1))

            Divider().background(AnalysisTheme.borderMedium)

            // Day rows
            ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                HStack(spacing: 0) {
                    Text(day)
                        .font(.analysisUI())
                        .foregroundColor(AnalysisTheme.textBody)
                        .frame(width: 60, alignment: .leading)
                        .padding(.horizontal, AnalysisTheme.Spacing.md)
                        .padding(.vertical, AnalysisTheme.Spacing.lg)

                    ForEach(exercise.columns, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(exerciseColor.opacity(0.3), lineWidth: 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AnalysisTheme.bgCard)
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .padding(.horizontal, AnalysisTheme.Spacing.sm)
                    }
                }
                
                if day != "Sun" {
                    Divider().background(AnalysisTheme.borderLight)
                }
            }
        }
        .background(AnalysisTheme.bgCard)
        .cornerRadius(AnalysisTheme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .stroke(AnalysisTheme.borderMedium, lineWidth: 1)
        )
    }
    
    // Mobile tracking cards (more compact for iPhone)
    private func mobileTrackingCards(_ exercise: TrackingExercise) -> some View {
        VStack(spacing: AnalysisTheme.Spacing.sm) {
            ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                VStack(spacing: AnalysisTheme.Spacing.xs) {
                    Text(day)
                        .font(.analysisUIBold())
                        .foregroundColor(AnalysisTheme.textHeading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(exercise.columns, id: \.self) { column in
                        HStack {
                            Text(column)
                                .font(.analysisUISmall())
                                .foregroundColor(AnalysisTheme.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(exerciseColor.opacity(0.3), lineWidth: 1.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(AnalysisTheme.bgCard)
                                )
                                .frame(width: 80, height: 32)
                        }
                    }
                }
                .padding(AnalysisTheme.Spacing.md)
                .background(AnalysisTheme.bgCard)
                .cornerRadius(AnalysisTheme.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md)
                        .stroke(AnalysisTheme.borderLight, lineWidth: 1)
                )
            }
        }
    }

    private func dialogueContent(_ exercise: DialogueExercise) -> some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.lg) {
            // Situation header
            HStack(spacing: 8) {
                Image(systemName: "person.2.badge.gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(exerciseColor)
                
                Text("PRACTICE DIALOGUE")
                    .font(.analysisUIBold())
                    .foregroundColor(exerciseColor)
                    .tracking(1)
            }
            
            Text(exercise.situation)
                .font(isIPad ? .analysisBodyLarge() : .analysisBody())
                .foregroundColor(AnalysisTheme.textMuted)
                .italic()

            // Dialogue pairs
            VStack(spacing: AnalysisTheme.Spacing.lg) {
                ForEach(exercise.dialoguePairs) { pair in
                    VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
                        // Instead of (what not to say)
                        HStack(alignment: .top, spacing: AnalysisTheme.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.red.opacity(0.8))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Instead of saying:")
                                    .font(.analysisUISmall())
                                    .foregroundColor(AnalysisTheme.textMuted)
                                    .tracking(0.5)
                                
                                Text("\"\(pair.insteadOf)\"")
                                    .font(.analysisBody())
                                    .foregroundColor(AnalysisTheme.textBody)
                                    .italic()
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        // Try instead (what to say)
                        HStack(alignment: .top, spacing: AnalysisTheme.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(AnalysisTheme.accentSuccess.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(AnalysisTheme.accentSuccess)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Try:")
                                    .font(.analysisUISmall())
                                    .foregroundColor(AnalysisTheme.accentSuccess)
                                    .tracking(0.5)
                                
                                Text("\"\(pair.tryThis)\"")
                                    .font(.analysisBody())
                                    .fontWeight(.medium)
                                    .foregroundColor(AnalysisTheme.textHeading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(AnalysisTheme.Spacing.md)
                        .background(AnalysisTheme.accentSuccess.opacity(0.05))
                        .cornerRadius(AnalysisTheme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md)
                                .stroke(AnalysisTheme.accentSuccess.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(AnalysisTheme.Spacing.lg)
                    .background(AnalysisTheme.bgCard)
                    .cornerRadius(AnalysisTheme.Radius.lg)
                    .overlay(
                        RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                            .stroke(AnalysisTheme.borderLight, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func patternInterruptContent(_ exercise: PatternInterruptExercise) -> some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.xl) {
            // Trigger situation
            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    
                    Text("WHEN YOU NOTICE:")
                        .font(.analysisUIBold())
                        .foregroundColor(.orange)
                        .tracking(1)
                }

                Text(exercise.triggerSituation)
                    .font(isIPad ? .analysisBodyLarge() : .analysisBody())
                    .fontWeight(.medium)
                    .foregroundColor(AnalysisTheme.textHeading)
                    .padding(AnalysisTheme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.08),
                                Color.orange.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(AnalysisTheme.Radius.lg)
                    .overlay(
                        RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 2)
                    )
            }

            // Cues header
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 14))
                    .foregroundColor(exerciseColor)
                
                Text("USE THESE CUES:")
                    .font(.analysisUIBold())
                    .foregroundColor(exerciseColor)
                    .tracking(1)
            }

            // Cues
            VStack(spacing: AnalysisTheme.Spacing.md) {
                // Physical cue
                cueRow(
                    icon: "hand.raised.fill",
                    iconColor: AnalysisTheme.accentOrange,
                    label: "Physical Cue",
                    content: exercise.physicalCue
                )

                // Verbal cue
                cueRow(
                    icon: "text.bubble.fill",
                    iconColor: AnalysisTheme.accentTeal,
                    label: "Verbal Cue",
                    content: exercise.verbalCue
                )

                // Mental cue
                cueRow(
                    icon: "brain.head.profile",
                    iconColor: AnalysisTheme.accentBurgundy,
                    label: "Mental Cue",
                    content: exercise.mentalCue
                )
            }
        }
    }

    private func cueRow(icon: String, iconColor: Color, label: String, content: String) -> some View {
        HStack(alignment: .top, spacing: AnalysisTheme.Spacing.lg) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md)
                    .fill(
                        LinearGradient(
                            colors: [iconColor.opacity(0.15), iconColor.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isIPad ? 56 : 48, height: isIPad ? 56 : 48)
                
                Image(systemName: icon)
                    .font(.system(size: isIPad ? 24 : 20))
                    .foregroundStyle(iconColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.analysisUIBold())
                    .foregroundColor(iconColor)
                    .tracking(0.5)

                Text(content)
                    .font(.analysisBody())
                    .foregroundColor(AnalysisTheme.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AnalysisTheme.Spacing.lg)
        .background(AnalysisTheme.bgCard)
        .cornerRadius(AnalysisTheme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .stroke(iconColor.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Rounded Corner Shape Helper
// Note: RoundedCorner is now defined in AnalysisComponents.swift to avoid duplication

#Preview("Legacy ExerciseView - Deprecated") {
    ScrollView {
        VStack(spacing: AnalysisTheme.Spacing.xl2) {
            ExerciseView(exercise: ReflectionExercise(
                title: "Identifying Your Inner Judge",
                prompt: "Think of a recent situation where you were hard on yourself. What exactly did your inner critic say? Whose voice does it remind you of?",
                estimatedTime: "10-15 min"
            ))

            ExerciseView(exercise: SelfAssessmentExercise(
                title: "Agreement Awareness",
                topic: "The Four Agreements",
                dimensions: [
                    AssessmentDimension(name: "Impeccability with Word", maxScore: 10),
                    AssessmentDimension(name: "Not Taking Things Personally", maxScore: 10),
                    AssessmentDimension(name: "Avoiding Assumptions", maxScore: 10),
                    AssessmentDimension(name: "Doing Your Best", maxScore: 10)
                ],
                scoringInterpretation: "8-10: Strong practice. 5-7: Room for growth. 1-4: Focus area for development.",
                estimatedTime: "5 min"
            ))
            
            ExerciseView(exercise: ScenarioExercise(
                title: "Responding to Criticism",
                scenario: "Your colleague publicly questions your work during a team meeting, suggesting your approach is inefficient.",
                question: "How can you respond in a way that maintains professional dignity while remaining open to feedback?",
                considerations: [
                    "Consider whether the feedback contains valid points worth examining",
                    "Notice your emotional reaction without being controlled by it",
                    "Think about how to request constructive dialogue in a private setting"
                ],
                estimatedTime: "15 min"
            ))

            ExerciseView(exercise: DialogueExercise(
                title: "Asking Instead of Assuming",
                situation: "Your friend hasn't texted back in two days",
                dialoguePairs: [
                    DialoguePair(insteadOf: "They must be upset with me", tryThis: "I wonder if everything is okay. I'll check in with them."),
                    DialoguePair(insteadOf: "They don't care about our friendship", tryThis: "They might be busy. When we connect, I can ask how they've been.")
                ],
                estimatedTime: "10 min"
            ))
            
            ExerciseView(exercise: PatternInterruptExercise(
                title: "Breaking the Assumption Spiral",
                triggerSituation: "You notice yourself creating stories about what someone \"probably\" thinks or feels",
                physicalCue: "Place your hand on your chest and take three slow breaths",
                verbalCue: "Say out loud: \"I'm making up a story. What do I actually know?\"",
                mentalCue: "Imagine the story written on a piece of paper, then visualize crumpling it up",
                estimatedTime: "5 min"
            ))
        }
        .padding(AnalysisTheme.Spacing.xl)
    }
    .background(AnalysisTheme.bgSecondary)
}
