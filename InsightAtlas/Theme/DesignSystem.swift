//
//  DesignSystem.swift
//  InsightAtlas
//
//  THE FINAL BLUEPRINT: Global Design System
//  This is the definitive, exhaustive technical specification.
//  Every value is literal. Every rule is absolute.
//

import SwiftUI

// MARK: - Design System

/// The unbreakable Design System for InsightAtlas
/// Based on the Forensic-Level UI/UX Specification
enum DesignSystem {

    // MARK: - Grid & Spacing System

    /// Core Unit: 1rem = 16px. All spacing MUST be multiples of 8px
    struct Spacing {
        static let unit: CGFloat = 8

        static let xs: CGFloat = 4        // 0.5 unit
        static let sm: CGFloat = 8        // 1 unit
        static let md: CGFloat = 16       // 2 units (1rem)
        static let lg: CGFloat = 24       // 3 units
        static let xl: CGFloat = 32       // 4 units
        static let xl2: CGFloat = 40      // 5 units
        static let xl3: CGFloat = 48      // 6 units
        static let xl4: CGFloat = 56      // 7 units
        static let xl5: CGFloat = 64      // 8 units

        /// Screen padding for iPhone (portrait, max-width: 600px)
        static let screenPaddingiPhone: CGFloat = 24

        /// Screen padding for iPad (min-width: 601px)
        static let screenPaddingiPad: CGFloat = 32
    }

    // MARK: - Color System (WCAG 2.1 AA Compliant)

    struct Colors {
        // Primary Interactive Color
        /// `#C85A3A` - Interactive elements, key borders
        /// WARNING: MUST NOT be used for text on light backgrounds
        static let primaryOrange = Color(hex: "#C85A3A")
        static let primaryOrangeHover = Color(hex: "#B44D2F")  // 10% darker for hover

        // Accent Colors
        /// `#4A7C59` - "Apply It" section backgrounds
        static let accentGreen = Color(hex: "#4A7C59")

        // Background Colors
        /// `#F8F8F8` - Main app background
        static let uiBackground = Color(hex: "#F8F8F8")
        /// `#FFFFFF` - Default card surface
        static let cardBackground = Color(hex: "#FFFFFF")

        // Text Colors (WCAG AA Compliant)
        /// `#1A1A1A` - Headings (Ratio on #FFFFFF: 15.28:1 - Passes AAA)
        static let textPrimary = Color(hex: "#1A1A1A")
        /// `#333333` - Body text (Ratio on #FFFFFF: 10.97:1 - Passes AAA)
        static let textSecondary = Color(hex: "#333333")
        /// `#666666` - Captions (Ratio on #FFFFFF: 4.68:1 - Passes AA)
        static let textTertiary = Color(hex: "#666666")
        /// Pure white for inverse text
        static let textInverse = Color.white

        // UI Colors
        /// `#EAEAEA` - Dividers, inactive borders
        static let uiBorder = Color(hex: "#EAEAEA")

        // Scrim Gradients for text protection on images
        static let scrimGradientDark = LinearGradient(
            colors: [
                Color.black.opacity(0.7),
                Color.black.opacity(0)
            ],
            startPoint: .top,
            endPoint: .center
        )

        static let scrimGradientLight = LinearGradient(
            colors: [
                Color.white.opacity(0.7),
                Color.white.opacity(0)
            ],
            startPoint: .top,
            endPoint: .center
        )
    }

    // MARK: - Typography System

    /// Font Family: Inter (exclusively)
    struct Typography {

        // MARK: - Display Style
        /// 36px, Bold (700), Letter Spacing: -1.5%, Line Height: 44px
        static func display() -> Font {
            if UIFont(name: "Inter-Bold", size: 36) != nil {
                return .custom("Inter-Bold", size: 36)
            }
            return .system(size: 36, weight: .bold)
        }

        // MARK: - Heading 1
        /// 28px, Bold (700), Letter Spacing: -1%, Line Height: 36px
        static func heading1() -> Font {
            if UIFont(name: "Inter-Bold", size: 28) != nil {
                return .custom("Inter-Bold", size: 28)
            }
            return .system(size: 28, weight: .bold)
        }

        // MARK: - Heading 2
        /// 22px, SemiBold (600), Letter Spacing: -0.5%, Line Height: 28px
        static func heading2() -> Font {
            if UIFont(name: "Inter-SemiBold", size: 22) != nil {
                return .custom("Inter-SemiBold", size: 22)
            }
            return .system(size: 22, weight: .semibold)
        }

        // MARK: - Heading 3
        /// 18px, SemiBold (600), Letter Spacing: 0%, Line Height: 24px
        static func heading3() -> Font {
            if UIFont(name: "Inter-SemiBold", size: 18) != nil {
                return .custom("Inter-SemiBold", size: 18)
            }
            return .system(size: 18, weight: .semibold)
        }

        // MARK: - Body Large
        /// 18px, Regular (400), Letter Spacing: 0%, Line Height: 28px
        static func bodyLarge() -> Font {
            if UIFont(name: "Inter-Regular", size: 18) != nil {
                return .custom("Inter-Regular", size: 18)
            }
            return .system(size: 18, weight: .regular)
        }

        // MARK: - Body Main
        /// 16px, Regular (400), Letter Spacing: 0%, Line Height: 26px
        static func bodyMain() -> Font {
            if UIFont(name: "Inter-Regular", size: 16) != nil {
                return .custom("Inter-Regular", size: 16)
            }
            return .system(size: 16, weight: .regular)
        }

        // MARK: - Caption
        /// 14px, Regular (400), Letter Spacing: +0.5%, Line Height: 20px
        static func caption() -> Font {
            if UIFont(name: "Inter-Regular", size: 14) != nil {
                return .custom("Inter-Regular", size: 14)
            }
            return .system(size: 14, weight: .regular)
        }

        // MARK: - Label
        /// 12px, Medium (500), Letter Spacing: +1%, Line Height: 16px
        static func label() -> Font {
            if UIFont(name: "Inter-Medium", size: 12) != nil {
                return .custom("Inter-Medium", size: 12)
            }
            return .system(size: 12, weight: .medium)
        }

        // MARK: - Button Label
        /// 12px, Bold (700) for button text
        static func buttonLabel() -> Font {
            if UIFont(name: "Inter-Bold", size: 12) != nil {
                return .custom("Inter-Bold", size: 12)
            }
            return .system(size: 12, weight: .bold)
        }
    }

    // MARK: - Corner Radius

    struct Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let button: CGFloat = 12
    }

    // MARK: - Component Sizes

    struct Components {
        /// Standard button height
        static let buttonHeight: CGFloat = 56

        /// Header height (sticky)
        static let headerHeight: CGFloat = 64

        /// Header blur amount
        static let headerBlur: CGFloat = 12

        /// Gap between carousel items
        static let carouselGap: CGFloat = 16

        /// Time column width for homework grid
        static let timeColumnWidth: CGFloat = 80
    }
}

// MARK: - View Extensions for Design System

extension View {
    /// Apply the Design System screen padding based on device
    func dsScreenPadding() -> some View {
        self.padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad
            ? DesignSystem.Spacing.screenPaddingiPad
            : DesignSystem.Spacing.screenPaddingiPhone)
    }

    /// Apply a dark scrim gradient for protecting light text on images
    func withDarkScrim() -> some View {
        self.overlay(
            DesignSystem.Colors.scrimGradientDark
                .allowsHitTesting(false)
        )
    }

    /// Apply a light scrim gradient for protecting dark text on images
    func withLightScrim() -> some View {
        self.overlay(
            DesignSystem.Colors.scrimGradientLight
                .allowsHitTesting(false)
        )
    }
}

// MARK: - Button Styles

/// Primary CTA Button Style
struct DSPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.buttonLabel())
            .foregroundColor(isEnabled ? DesignSystem.Colors.textInverse : Color(hex: "#999999"))
            .frame(height: DesignSystem.Components.buttonHeight)
            .frame(maxWidth: .infinity)
            .background(
                isEnabled
                    ? (configuration.isPressed
                        ? DesignSystem.Colors.primaryOrangeHover
                        : DesignSystem.Colors.primaryOrange)
                    : DesignSystem.Colors.uiBorder
            )
            .cornerRadius(DesignSystem.Radius.button)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Secondary Button Style (outlined)
struct DSSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.buttonLabel())
            .foregroundColor(isEnabled ? DesignSystem.Colors.primaryOrange : Color(hex: "#999999"))
            .frame(height: DesignSystem.Components.buttonHeight)
            .frame(maxWidth: .infinity)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.button)
                    .stroke(
                        isEnabled ? DesignSystem.Colors.primaryOrange : DesignSystem.Colors.uiBorder,
                        lineWidth: 2
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DSPrimaryButtonStyle {
    static var dsPrimary: DSPrimaryButtonStyle { DSPrimaryButtonStyle() }
}

extension ButtonStyle where Self == DSSecondaryButtonStyle {
    static var dsSecondary: DSSecondaryButtonStyle { DSSecondaryButtonStyle() }
}

// MARK: - Card Style

struct DSCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.Radius.lg)
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func dsCard() -> some View {
        modifier(DSCardStyle())
    }
}

// MARK: - Header Style

struct DSStickyHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(height: DesignSystem.Components.headerHeight)
            .frame(maxWidth: .infinity)
            .background(
                Color(hex: "#F8F8F8").opacity(0.85)
                    .background(.ultraThinMaterial)
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(DesignSystem.Colors.uiBorder)
                    .frame(height: 1)
            }
    }
}

extension View {
    func dsStickyHeader() -> some View {
        modifier(DSStickyHeaderStyle())
    }
}

// MARK: - Apply It Section Style (CTX-04 Fix)

struct DSApplyItStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(DesignSystem.Typography.bodyLarge())  // 18px for Large Text compliance
            .fontWeight(.medium)  // Weight 500
            .foregroundColor(DesignSystem.Colors.textInverse)
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.accentGreen)
            .cornerRadius(DesignSystem.Radius.lg)
    }
}

extension View {
    /// Apply the "Apply It" section style with WCAG compliant contrast
    func dsApplyItSection() -> some View {
        modifier(DSApplyItStyle())
    }
}

// MARK: - Text Styles

extension View {
    func dsDisplay() -> some View {
        self
            .font(DesignSystem.Typography.display())
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .tracking(-0.54)  // -1.5% letter spacing
            .lineSpacing(8)   // 44px line height - 36px font size
    }

    func dsHeading1() -> some View {
        self
            .font(DesignSystem.Typography.heading1())
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .tracking(-0.28)  // -1% letter spacing
            .lineSpacing(8)   // 36px line height - 28px font size
    }

    func dsHeading2() -> some View {
        self
            .font(DesignSystem.Typography.heading2())
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .tracking(-0.11)  // -0.5% letter spacing
            .lineSpacing(6)   // 28px line height - 22px font size
    }

    func dsHeading3() -> some View {
        self
            .font(DesignSystem.Typography.heading3())
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .lineSpacing(6)   // 24px line height - 18px font size
    }

    func dsBodyLarge() -> some View {
        self
            .font(DesignSystem.Typography.bodyLarge())
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .lineSpacing(10)  // 28px line height - 18px font size
    }

    func dsBodyMain() -> some View {
        self
            .font(DesignSystem.Typography.bodyMain())
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .lineSpacing(10)  // 26px line height - 16px font size
    }

    func dsCaption() -> some View {
        self
            .font(DesignSystem.Typography.caption())
            .foregroundColor(DesignSystem.Colors.textTertiary)
            .tracking(0.07)   // +0.5% letter spacing
            .lineSpacing(6)   // 20px line height - 14px font size
    }

    func dsLabel() -> some View {
        self
            .font(DesignSystem.Typography.label())
            .foregroundColor(DesignSystem.Colors.textTertiary)
            .tracking(0.12)   // +1% letter spacing
            .lineSpacing(4)   // 16px line height - 12px font size
    }
}

// MARK: - Weekly Homework Grid Component

/// Data model for a homework task within the grid
struct HomeworkTask: Identifiable, Equatable {
    let id: UUID
    var title: String
    var conceptName: String
    var timeframe: String?
    var isCompleted: Bool = false
    var dayAssigned: WeekDay

    init(
        id: UUID = UUID(),
        title: String,
        conceptName: String,
        timeframe: String? = nil,
        isCompleted: Bool = false,
        dayAssigned: WeekDay
    ) {
        self.id = id
        self.title = title
        self.conceptName = conceptName
        self.timeframe = timeframe
        self.isCompleted = isCompleted
        self.dayAssigned = dayAssigned
    }

    static func == (lhs: HomeworkTask, rhs: HomeworkTask) -> Bool {
        lhs.id == rhs.id
    }
}

enum WeekDay: String, CaseIterable, Identifiable {
    case monday = "Mon"
    case tuesday = "Tue"
    case wednesday = "Wed"
    case thursday = "Thu"
    case friday = "Fri"
    case saturday = "Sat"
    case sunday = "Sun"

    var id: String { rawValue }

    var fullName: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }
}

/// Weekly Homework Grid following THE FINAL BLUEPRINT specification
/// Features: 80px time column, 8px grid alignment, WCAG AA compliant colors
struct DSWeeklyHomeworkGrid: View {
    let tasks: [HomeworkTask]
    let onTaskToggle: ((HomeworkTask) -> Void)?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    init(tasks: [HomeworkTask], onTaskToggle: ((HomeworkTask) -> Void)? = nil) {
        self.tasks = tasks
        self.onTaskToggle = onTaskToggle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryOrange)

                Text("WEEKLY HOMEWORK")
                    .font(DesignSystem.Typography.label())
                    .fontWeight(.bold)
                    .tracking(1.2)
                    .foregroundStyle(DesignSystem.Colors.primaryOrange)
            }
            .padding(.bottom, DesignSystem.Spacing.sm)

            if isIPad {
                iPadGridLayout
            } else {
                iPhoneCardLayout
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.Radius.lg)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - iPad Grid Layout (Table format)

    private var iPadGridLayout: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("Day")
                    .font(DesignSystem.Typography.label())
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(width: DesignSystem.Components.timeColumnWidth, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)

                Text("Task")
                    .font(DesignSystem.Typography.label())
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)

                Text("Time")
                    .font(DesignSystem.Typography.label())
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(width: DesignSystem.Components.timeColumnWidth, alignment: .center)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)

                Text("Done")
                    .font(DesignSystem.Typography.label())
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(width: 60, alignment: .center)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.sm)
            }
            .background(DesignSystem.Colors.primaryOrange.opacity(0.1))

            Divider()
                .background(DesignSystem.Colors.uiBorder)

            // Day rows
            ForEach(WeekDay.allCases) { day in
                let dayTasks = tasks.filter { $0.dayAssigned == day }

                if dayTasks.isEmpty {
                    emptyDayRow(day: day)
                } else {
                    ForEach(dayTasks) { task in
                        taskRow(task: task, day: day, showDay: task == dayTasks.first)
                    }
                }

                if day != .sunday {
                    Divider()
                        .background(DesignSystem.Colors.uiBorder)
                }
            }
        }
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .stroke(DesignSystem.Colors.uiBorder, lineWidth: 1)
        )
    }

    private func emptyDayRow(day: WeekDay) -> some View {
        HStack(spacing: 0) {
            Text(day.rawValue)
                .font(DesignSystem.Typography.bodyMain())
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: DesignSystem.Components.timeColumnWidth, alignment: .leading)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.lg)

            Text("No tasks")
                .font(DesignSystem.Typography.bodyMain())
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .italic()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignSystem.Spacing.md)

            Spacer()
                .frame(width: DesignSystem.Components.timeColumnWidth + 60 + DesignSystem.Spacing.md * 2)
        }
    }

    private func taskRow(task: HomeworkTask, day: WeekDay, showDay: Bool) -> some View {
        HStack(spacing: 0) {
            // Day column
            Text(showDay ? day.rawValue : "")
                .font(DesignSystem.Typography.bodyMain())
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: DesignSystem.Components.timeColumnWidth, alignment: .leading)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.md)

            // Task column
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(task.title)
                    .font(DesignSystem.Typography.bodyMain())
                    .foregroundColor(task.isCompleted ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textSecondary)
                    .strikethrough(task.isCompleted)

                Text(task.conceptName)
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.Spacing.md)

            // Time column
            if let timeframe = task.timeframe {
                Text(timeframe)
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .frame(width: DesignSystem.Components.timeColumnWidth, alignment: .center)
                    .padding(.horizontal, DesignSystem.Spacing.md)
            } else {
                Spacer()
                    .frame(width: DesignSystem.Components.timeColumnWidth)
            }

            // Checkbox
            Button {
                onTaskToggle?(task)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                        .stroke(
                            task.isCompleted ? DesignSystem.Colors.accentGreen : DesignSystem.Colors.uiBorder,
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)

                    if task.isCompleted {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                            .fill(DesignSystem.Colors.accentGreen)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(width: 60)
            .padding(.horizontal, DesignSystem.Spacing.sm)
        }
    }

    // MARK: - iPhone Card Layout

    private var iPhoneCardLayout: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(WeekDay.allCases) { day in
                let dayTasks = tasks.filter { $0.dayAssigned == day }

                if !dayTasks.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        // Day header
                        Text(day.fullName)
                            .font(DesignSystem.Typography.label())
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.primaryOrange)
                            .tracking(0.5)

                        // Tasks for this day
                        ForEach(dayTasks) { task in
                            iPhoneTaskCard(task: task)
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.uiBackground)
                    .cornerRadius(DesignSystem.Radius.md)
                }
            }
        }
    }

    private func iPhoneTaskCard(task: HomeworkTask) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Checkbox
            Button {
                onTaskToggle?(task)
            } label: {
                ZStack {
                    Circle()
                        .stroke(
                            task.isCompleted ? DesignSystem.Colors.accentGreen : DesignSystem.Colors.uiBorder,
                            lineWidth: 2
                        )
                        .frame(width: 28, height: 28)

                    if task.isCompleted {
                        Circle()
                            .fill(DesignSystem.Colors.accentGreen)
                            .frame(width: 28, height: 28)

                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }

            // Task info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(task.title)
                    .font(DesignSystem.Typography.bodyMain())
                    .foregroundColor(task.isCompleted ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textSecondary)
                    .strikethrough(task.isCompleted)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(task.conceptName)
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    if let timeframe = task.timeframe {
                        Text("•")
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        Text(timeframe)
                            .font(DesignSystem.Typography.caption())
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.Radius.sm)
    }
}

// MARK: - Book Carousel Component

/// Data model for a book in the carousel
struct CarouselBook: Identifiable {
    let id: UUID
    var title: String
    var author: String
    var coverImagePath: String?
    var coverImage: UIImage?
    var readProgress: Double? // 0.0 to 1.0
    var isCompleted: Bool
}

/// Home Screen Book Carousel following THE FINAL BLUEPRINT specification
/// Features: 16px gap between items, snap scrolling, WCAG AA compliant
struct DSBookCarousel: View {
    let books: [CarouselBook]
    let onBookTap: ((CarouselBook) -> Void)?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    private var cardWidth: CGFloat {
        isIPad ? 160 : 120
    }

    private var cardHeight: CGFloat {
        isIPad ? 240 : 180
    }

    init(books: [CarouselBook], onBookTap: ((CarouselBook) -> Void)? = nil) {
        self.books = books
        self.onBookTap = onBookTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section header
            HStack {
                Text("Continue Reading")
                    .font(DesignSystem.Typography.heading2())
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                Button {
                    // See all action
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text("See All")
                            .font(DesignSystem.Typography.caption())
                            .fontWeight(.medium)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(DesignSystem.Colors.primaryOrange)
                }
            }
            .padding(.horizontal, isIPad ? DesignSystem.Spacing.screenPaddingiPad : DesignSystem.Spacing.screenPaddingiPhone)

            // Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Components.carouselGap) {
                    ForEach(books) { book in
                        bookCard(book: book)
                    }
                }
                .padding(.horizontal, isIPad ? DesignSystem.Spacing.screenPaddingiPad : DesignSystem.Spacing.screenPaddingiPhone)
            }
        }
    }

    private func bookCard(book: CarouselBook) -> some View {
        Button {
            onBookTap?(book)
        } label: {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Cover image
                ZStack(alignment: .bottomLeading) {
                    // Book cover
                    if let image = book.coverImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cardWidth, height: cardHeight * 0.7)
                            .clipped()
                    } else {
                        // Placeholder
                        ZStack {
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primaryOrange.opacity(0.3),
                                    DesignSystem.Colors.primaryOrange.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )

                            VStack(spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: isIPad ? 32 : 24))
                                    .foregroundColor(DesignSystem.Colors.primaryOrange.opacity(0.5))
                            }
                        }
                        .frame(width: cardWidth, height: cardHeight * 0.7)
                    }

                    // Progress indicator
                    if let progress = book.readProgress, !book.isCompleted {
                        progressBadge(progress: progress)
                            .padding(DesignSystem.Spacing.sm)
                    }

                    // Completed badge
                    if book.isCompleted {
                        completedBadge
                            .padding(DesignSystem.Spacing.sm)
                    }
                }
                .cornerRadius(DesignSystem.Radius.md)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                // Book info
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(book.title)
                        .font(DesignSystem.Typography.caption())
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(book.author)
                        .font(DesignSystem.Typography.label())
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .lineLimit(1)
                }
                .frame(width: cardWidth, alignment: .leading)
            }
            .frame(width: cardWidth)
        }
        .buttonStyle(.plain)
    }

    private func progressBadge(progress: Double) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 16, height: 16)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .rotationEffect(.degrees(-90))
            }

            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(Color.black.opacity(0.6))
        .cornerRadius(DesignSystem.Radius.sm)
    }

    private var completedBadge: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
            Text("Done")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(DesignSystem.Colors.accentGreen)
        .cornerRadius(DesignSystem.Radius.sm)
    }
}

// MARK: - Preview

#Preview("Weekly Homework Grid") {
    ScrollView {
        VStack(spacing: DesignSystem.Spacing.xl) {
            DSWeeklyHomeworkGrid(
                tasks: [
                    HomeworkTask(
                        title: "Notice assumption spirals",
                        conceptName: "Don't Make Assumptions",
                        timeframe: "5 min",
                        isCompleted: false,
                        dayAssigned: .monday
                    ),
                    HomeworkTask(
                        title: "Practice one clarifying question",
                        conceptName: "Communication",
                        timeframe: "10 min",
                        isCompleted: true,
                        dayAssigned: .monday
                    ),
                    HomeworkTask(
                        title: "Journal reflection",
                        conceptName: "Self-Awareness",
                        timeframe: "15 min",
                        isCompleted: false,
                        dayAssigned: .wednesday
                    ),
                    HomeworkTask(
                        title: "Evening review",
                        conceptName: "Always Do Your Best",
                        timeframe: "5 min",
                        isCompleted: false,
                        dayAssigned: .friday
                    )
                ]
            )
        }
        .padding()
    }
    .background(DesignSystem.Colors.uiBackground)
}

#Preview("Book Carousel") {
    VStack {
        DSBookCarousel(
            books: [
                CarouselBook(
                    id: UUID(),
                    title: "The Four Agreements",
                    author: "Don Miguel Ruiz",
                    readProgress: 0.65,
                    isCompleted: false
                ),
                CarouselBook(
                    id: UUID(),
                    title: "Atomic Habits",
                    author: "James Clear",
                    readProgress: 0.30,
                    isCompleted: false
                ),
                CarouselBook(
                    id: UUID(),
                    title: "Deep Work",
                    author: "Cal Newport",
                    isCompleted: true
                ),
                CarouselBook(
                    id: UUID(),
                    title: "The Power of Now",
                    author: "Eckhart Tolle",
                    readProgress: 0.10,
                    isCompleted: false
                )
            ]
        )
    }
    .background(DesignSystem.Colors.uiBackground)
}

// MARK: - iPad Multi-Column Layout System

/// Responsive layout configuration for iPad
struct DSResponsiveLayout {
    /// iPad breakpoint (min-width: 601px as per specification)
    static let iPadBreakpoint: CGFloat = 601

    /// Maximum content width for readability on large screens
    static let maxContentWidth: CGFloat = 1200

    /// Sidebar width for iPad split view
    static let sidebarWidth: CGFloat = 320

    /// Master/detail split ratio
    static let splitRatio: CGFloat = 0.35
}

/// Adaptive layout container that switches between single column (iPhone) and multi-column (iPad)
struct DSAdaptiveContainer<Content: View, Sidebar: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let sidebar: Sidebar
    let content: Content
    var showSidebar: Bool = true

    init(
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder content: () -> Content
    ) {
        self.sidebar = sidebar()
        self.content = content()
    }

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        if isIPad && showSidebar {
            HStack(spacing: 0) {
                // Sidebar
                sidebar
                    .frame(width: DSResponsiveLayout.sidebarWidth)
                    .background(DesignSystem.Colors.uiBackground)

                // Divider
                Rectangle()
                    .fill(DesignSystem.Colors.uiBorder)
                    .frame(width: 1)

                // Main content
                content
                    .frame(maxWidth: .infinity)
            }
        } else {
            // Single column for iPhone
            content
        }
    }
}

/// Two-column grid layout for iPad content areas
struct DSTwoColumnGrid<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = DesignSystem.Spacing.lg, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        if isIPad {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: spacing),
                    GridItem(.flexible(), spacing: spacing)
                ],
                spacing: spacing
            ) {
                content()
            }
        } else {
            LazyVStack(spacing: spacing) {
                content()
            }
        }
    }
}

/// Three-column grid layout for iPad (book library, cards, etc.)
struct DSThreeColumnGrid<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = DesignSystem.Spacing.md, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        if isIPad {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: spacing),
                    GridItem(.flexible(), spacing: spacing),
                    GridItem(.flexible(), spacing: spacing)
                ],
                spacing: spacing
            ) {
                content()
            }
        } else {
            // Two columns for iPhone (landscape) or single column (portrait)
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: spacing),
                    GridItem(.flexible(), spacing: spacing)
                ],
                spacing: spacing
            ) {
                content()
            }
        }
    }
}

/// Responsive content wrapper that applies appropriate padding and max width
struct DSResponsiveContent<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        content
            .padding(.horizontal, isIPad
                ? DesignSystem.Spacing.screenPaddingiPad
                : DesignSystem.Spacing.screenPaddingiPhone)
            .frame(maxWidth: isIPad ? DSResponsiveLayout.maxContentWidth : .infinity)
    }
}

// MARK: - iPhone Responsive Behaviors

/// Compact mode container for space-constrained iPhone layouts
struct DSCompactContainer<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    /// Returns true if we should use compact layout (iPhone in portrait or small text)
    private var useCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    /// Returns true if accessibility text size is being used
    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        content
            .environment(\.dsCompactMode, useCompactLayout)
            .environment(\.dsAccessibilityMode, isAccessibilitySize)
    }
}

/// Environment key for compact mode
private struct DSCompactModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

/// Environment key for accessibility mode
private struct DSAccessibilityModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var dsCompactMode: Bool {
        get { self[DSCompactModeKey.self] }
        set { self[DSCompactModeKey.self] = newValue }
    }

    var dsAccessibilityMode: Bool {
        get { self[DSAccessibilityModeKey.self] }
        set { self[DSAccessibilityModeKey.self] = newValue }
    }
}

/// Adaptive stack that switches between HStack and VStack based on available space
struct DSAdaptiveStack<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dsCompactMode) private var compactMode

    let horizontalAlignment: HorizontalAlignment
    let verticalAlignment: VerticalAlignment
    let spacing: CGFloat
    let content: () -> Content

    init(
        horizontalAlignment: HorizontalAlignment = .center,
        verticalAlignment: VerticalAlignment = .center,
        spacing: CGFloat = DesignSystem.Spacing.md,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.spacing = spacing
        self.content = content
    }

    private var useHorizontal: Bool {
        horizontalSizeClass == .regular && !compactMode
    }

    var body: some View {
        if useHorizontal {
            HStack(alignment: verticalAlignment, spacing: spacing) {
                content()
            }
        } else {
            VStack(alignment: horizontalAlignment, spacing: spacing) {
                content()
            }
        }
    }
}

/// Responsive font size modifier that adjusts for device and accessibility
struct DSResponsiveFontModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let baseSize: CGFloat
    let weight: Font.Weight

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    private var adjustedSize: CGFloat {
        // iPad gets slightly larger fonts for readability at arm's length
        let iPadMultiplier: CGFloat = isIPad ? 1.1 : 1.0
        return baseSize * iPadMultiplier
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: adjustedSize, weight: weight))
    }
}

extension View {
    func dsResponsiveFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(DSResponsiveFontModifier(baseSize: size, weight: weight))
    }
}

/// Responsive spacing modifier
struct DSResponsiveSpacingModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let compactSpacing: CGFloat
    let regularSpacing: CGFloat

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    private var effectiveSpacing: CGFloat {
        isIPad ? regularSpacing : compactSpacing
    }

    func body(content: Content) -> some View {
        content
            .padding(effectiveSpacing)
    }
}

extension View {
    func dsResponsiveSpacing(compact: CGFloat = DesignSystem.Spacing.md, regular: CGFloat = DesignSystem.Spacing.lg) -> some View {
        modifier(DSResponsiveSpacingModifier(compactSpacing: compact, regularSpacing: regular))
    }
}

// MARK: - Library Grid View (iPad optimized)

/// Book library grid that shows 2 columns on iPhone, 3-4 columns on iPad
struct DSLibraryGrid<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    private var columns: [GridItem] {
        if isIPad {
            return [
                GridItem(.adaptive(minimum: 160, maximum: 200), spacing: DesignSystem.Components.carouselGap)
            ]
        } else {
            return [
                GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
                GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
            ]
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.lg) {
            content()
        }
        .padding(.horizontal, isIPad
            ? DesignSystem.Spacing.screenPaddingiPad
            : DesignSystem.Spacing.screenPaddingiPhone)
    }
}

#Preview("iPad Two-Column Layout") {
    DSTwoColumnGrid {
        ForEach(0..<6) { index in
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .fill(DesignSystem.Colors.primaryOrange.opacity(0.2))
                .frame(height: 120)
                .overlay(
                    Text("Card \(index + 1)")
                        .font(DesignSystem.Typography.heading3())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                )
        }
    }
    .padding()
    .background(DesignSystem.Colors.uiBackground)
}

#Preview("Responsive Library Grid") {
    ScrollView {
        DSLibraryGrid {
            ForEach(0..<12) { index in
                VStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primaryOrange.opacity(0.3),
                                    DesignSystem.Colors.primaryOrange.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .aspectRatio(0.65, contentMode: .fit)
                        .overlay(
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 32))
                                .foregroundColor(DesignSystem.Colors.primaryOrange.opacity(0.5))
                        )

                    Text("Book \(index + 1)")
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)

                    Text("Author Name")
                        .font(DesignSystem.Typography.label())
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
        }
    }
    .background(DesignSystem.Colors.uiBackground)
}
