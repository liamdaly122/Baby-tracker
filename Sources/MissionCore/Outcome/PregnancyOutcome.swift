import Foundation

/// How things ended up, recorded once (review action 10). Anything but `allWell` turns the app
/// quiet: no humour, no countdown, no celebration, and no LAUNCH after a loss. The copy here is
/// for a bereavement midwife's review (content review log L1 to L6).
public enum PregnancyOutcome: String, Codable, Sendable, CaseIterable {
    /// The baby's here and everyone is doing well.
    case allWell
    /// The baby is in neonatal care or needs extra care.
    case babyNeedsCare
    /// She needs extra care after the birth.
    case sheNeedsCare
    /// The baby died, before or after birth, at any week.
    case loss

    /// The answers to "How is everyone?", in the order they're offered.
    public var choice: String {
        switch self {
        case .allWell: "Everyone is doing well"
        case .babyNeedsCare: "The baby needs extra care"
        case .sheNeedsCare: "She needs extra care"
        case .loss: "We lost our baby"
        }
    }

    /// Whether the app keeps its lighter side: humour, the space story, celebrations.
    public var keepsHumour: Bool { self == .allWell }

    /// Whether a birth message makes sense.
    public var hasBirthMessage: Bool { self != .loss }

    /// The first words of the birth message. No wellbeing claim unless he writes one.
    public func messageOpener(babyName: String, bornAt time: String) -> String {
        let name = babyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let born = name.isEmpty ? "Our baby was born at \(time)." : "\(name) was born at \(time)."
        return self == .allWell ? "Baby's here! \(born)" : born
    }

    /// What the message says about how they're doing until he changes it. Only "all well" says
    /// anything: otherwise it's his to write, or leave out.
    public var defaultWellbeing: String {
        self == .allWell ? "Mum and baby are doing well." : ""
    }
}

/// Somewhere to turn: a support line, a page, or what to know about leave and registration.
public struct SupportItem: Sendable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public var detail: String
    public var number: PhoneNumber?
    public var link: URL?
    public var source: CopySource
}

/// Support for each outcome, from research report 05. UK only for now: the US version says to ask
/// the hospital team. Shown, never pushed: nothing here sends a notification.
public enum SupportDirectory {
    /// The heading and a line under it, for the support screen.
    public static func heading(for outcome: PregnancyOutcome) -> (title: String, detail: String) {
        switch outcome {
        case .loss:
            (
                "We're so sorry",
                "There's nothing you need to do in this app. When you're ready, these people can help, you and her."
            )
        case .babyNeedsCare:
            ("Support while your baby is cared for", "Neonatal care is hard on parents too. These can help.")
        case .sheNeedsCare:
            ("Support while she's cared for", "Ask the team looking after her what's happening and what you can do.")
        case .allWell:
            ("Congratulations", "")
        }
    }

    /// Support for an outcome. `gestationalAgeDays` puts the right line first after a loss.
    public static func items(
        for outcome: PregnancyOutcome, region: ContentRegion, gestationalAgeDays: Int?
    ) -> [SupportItem] {
        guard region == .uk else {
            return outcome == .allWell ? [] : [askTheTeam]
        }
        switch outcome {
        case .loss:
            let early = gestationalAgeDays.map { $0 < Self.stillbirthFromDays } ?? false
            var items = early ? [miscarriageUK, sands] : [sands, miscarriageUK]
            items += [tommys, samaritans]
            if !early {
                items += [registerStillbirth, leaveAfterLoss]
            }
            return items
        case .babyNeedsCare:
            return [bliss, neonatalLeave, samaritans]
        case .sheNeedsCare:
            return [samaritans]
        case .allWell:
            return []
        }
    }

    /// 24+0: from here, NHS calls a loss a stillbirth, and leave and registration rules apply.
    public static let stillbirthFromDays = 168

    // MARK: Items

    static let sands = SupportItem(
        id: "sands", title: "Sands",
        detail: "For anyone affected by the death of a baby. Weekdays 10am to 3pm, and 6pm to 9pm Tuesday to Thursday.",
        number: PhoneNumber.parse("0808 164 3332", region: .uk).value,
        link: URL(string: "https://www.sands.org.uk/support-you/how-we-offer-support/helpline"),
        source: CopySource(
            title: "Sands: Baby Loss Helpline",
            url: url("https://www.sands.org.uk/support-you/how-we-offer-support/helpline")))

    static let miscarriageUK = SupportItem(
        id: "miscarriage-uk", title: "Miscarriage UK (the Miscarriage Association)",
        detail: "For anyone affected by miscarriage. 9am to 8pm Monday, Wednesday and Friday, 9am to 4pm Tuesday "
            + "and Thursday.",
        number: PhoneNumber.parse("0303 003 6464", region: .uk).value,
        link: URL(string: "https://www.miscarriageuk.org/"),
        source: CopySource(title: "Miscarriage UK", url: url("https://www.miscarriageuk.org/")))

    static let tommys = SupportItem(
        id: "tommys", title: "Tommy's",
        detail: "Midwives you can talk to, and a page for dads and partners: you've lost a baby too.",
        number: PhoneNumber.parse("0800 0147 800", region: .uk).value,
        link: URL(string: "https://www.tommys.org/baby-loss-support/dads-and-partners"),
        source: CopySource(
            title: "Tommy's: Baby loss support for dads and partners",
            url: url("https://www.tommys.org/baby-loss-support/dads-and-partners")))

    static let samaritans = SupportItem(
        id: "samaritans", title: "Samaritans",
        detail: "Any time, day or night, free from any phone.",
        number: PhoneNumber.shortCode("116123"),
        link: nil,
        source: CopySource(
            title: "Samaritans: Contact us", url: url("https://www.samaritans.org/how-we-can-help/contact-samaritan/")))

    static let bliss = SupportItem(
        id: "bliss", title: "Bliss",
        detail: "For families of premature and sick babies: emotional and practical support, including video calls.",
        number: nil,
        link: URL(string: "https://www.bliss.org.uk/parents/support"),
        source: CopySource(title: "Bliss: Support", url: url("https://www.bliss.org.uk/parents/support")))

    static let neonatalLeave = SupportItem(
        id: "neonatal-leave", title: "Neonatal Care Leave and Pay",
        detail: "If neonatal care starts in the first 28 days, you may get a week's paid leave for every 7 full days "
            + "of care, up to 12 weeks, on top of paternity leave. Tell your employer.",
        number: nil,
        link: URL(string: "https://www.gov.uk/neonatal-care-pay-leave"),
        source: CopySource(
            title: "GOV.UK: Neonatal Care Pay and Leave", url: url("https://www.gov.uk/neonatal-care-pay-leave")))

    static let registerStillbirth = SupportItem(
        id: "register-stillbirth", title: "Registering your baby",
        detail: "When you're ready: a stillbirth is registered within 42 days in England and Wales (21 in Scotland). "
            + "You can name your baby in the register. The hospital can help.",
        number: nil,
        link: URL(string: "https://www.gov.uk/register-stillbirth"),
        source: CopySource(title: "GOV.UK: Register a stillbirth", url: url("https://www.gov.uk/register-stillbirth")))

    static let leaveAfterLoss = SupportItem(
        id: "leave-after-loss", title: "Time off work",
        detail: "You can still take paternity leave after a stillbirth from 24 weeks, and you may get 2 weeks' "
            + "Parental Bereavement Leave, taken within 56 weeks.",
        number: nil,
        link: URL(string: "https://www.gov.uk/parental-bereavement-pay-leave"),
        source: CopySource(
            title: "GOV.UK: Parental Bereavement Pay and Leave",
            url: url("https://www.gov.uk/parental-bereavement-pay-leave")))

    static let askTheTeam = SupportItem(
        id: "ask-the-team", title: "Ask the hospital team",
        detail: "They can tell you what support is available where you are.",
        number: nil, link: nil,
        source: CopySource(title: "Research report 05", url: url("https://www.nhs.uk/conditions/stillbirth/")))

    /// Every item, for tests and the content review.
    public static let all = [
        sands, miscarriageUK, tommys, samaritans, bliss, neonatalLeave, registerStillbirth, leaveAfterLoss, askTheTeam,
    ]

    private static func url(_ string: String) -> URL {
        URL(string: string) ?? URL(fileURLWithPath: "/")
    }
}

extension Result {
    /// The value if it succeeded.
    var value: Success? { try? get() }
}
