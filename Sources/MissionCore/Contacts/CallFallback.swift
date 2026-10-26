import Foundation

/// One thing to try when the maternity unit doesn't answer.
public struct CallStep: Sendable, Hashable {
    public var title: String
    public var detail: String
    public var number: PhoneNumber?
}

/// "Can't get through?" The NHS says to call 111 if you can't reach your midwife or maternity unit,
/// and 999 in an emergency. Shown under the main call button whenever it's in view.
public enum CallFallback {
    public static func steps(region: ContentRegion, unit: PhoneNumber?, labourWard: PhoneNumber?) -> [CallStep] {
        var steps: [CallStep] = []
        if let unit {
            steps.append(CallStep(title: "Try again", detail: "Ring the same number again.", number: unit))
        }
        if let labourWard {
            switch region {
            case .uk:
                steps.append(
                    CallStep(
                        title: "Call the labour ward", detail: "Ask for the labour ward.",
                        number: labourWard))
            case .us:
                steps.append(
                    CallStep(
                        title: "Call labor and delivery", detail: "Ask for labor and delivery.",
                        number: labourWard))
            }
        }
        if region == .uk {
            steps.append(
                CallStep(
                    title: "Call NHS 111", detail: "If you can't reach your maternity unit.",
                    number: PhoneNumber.shortCode("111"))
            )
        }
        let emergency = StateCopy.emergencyNumber(region)
        steps.append(
            CallStep(
                title: "Call \(emergency) if it's an emergency",
                detail: "If she has a strong urge to push, you can see or feel the cord, there's heavy bleeding, "
                    + "or she has a seizure or collapses.",
                number: PhoneNumber.shortCode(emergency)
            )
        )
        return steps
    }

    public static let source = CopySource(
        title: "NHS: Signs that labour has begun",
        url: URL(string: "https://www.nhs.uk/pregnancy/labour-and-birth/signs-of-labour/signs-that-labour-has-begun/")
            ?? URL(fileURLWithPath: "/")
    )
}
