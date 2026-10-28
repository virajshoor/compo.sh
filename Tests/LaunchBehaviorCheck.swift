import AppKit
import CoreServices

@main
enum LaunchBehaviorCheck {
    static func main() {
        assert(!LaunchBehavior.isLoginLaunch(nil))
        let event = NSAppleEventDescriptor(eventClass: kCoreEventClass, eventID: kAEOpenApplication,
            targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        assert(!LaunchBehavior.isLoginLaunch(event))
        event.setParam(NSAppleEventDescriptor(enumCode: keyAELaunchedAsLogInItem), forKeyword: keyAEPropData)
        assert(LaunchBehavior.isLoginLaunch(event))
        event.setParam(NSAppleEventDescriptor(enumCode: keyAELaunchedAsServiceItem), forKeyword: keyAEPropData)
        assert(!LaunchBehavior.isLoginLaunch(event))
        print("Login launch checks passed: absent, manual, login, service.")
    }
}
