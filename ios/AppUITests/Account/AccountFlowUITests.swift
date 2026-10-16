import XCTest

/// Account flows end to end on in-memory data: the app runs with `-account-ui-test-scenario <name>`
/// (App/Sources/Features/Account/Testing/AccountUITestScenario.swift): `signed-out` (fresh install, SMS code 123456),
/// `signed-in` (an onboarded member without groups), `with-groups` (a member in two groups with photos).
final class AccountFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ scenario: String, _ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-account-ui-test-scenario", scenario] + extra
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The text field carrying `identifier` (the identifier is set on the form field around it).
    private func field(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let textField = app.textFields[identifier]
        return textField.exists ? textField : element(app, identifier)
    }

    @MainActor
    private func type(_ text: String, into identifier: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let target = field(app, identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "\(identifier) missing", file: file, line: line)
        target.tap()
        // One key at a time: the phone and birthday fields reformat as they are typed (separators inserted), and a
        // burst of keys typed while the field rewrites its text loses some of them.
        for character in text {
            target.typeText(String(character))
        }
    }

    /// The control carrying `identifier`: the button when there is one (a block's identifier also reaches its title and
    /// detail text), else any element.
    @MainActor
    private func tap(_ identifier: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let candidate = app.buttons.matching(identifier: identifier).firstMatch
        let button = candidate.waitForExistence(timeout: 2) ? candidate : element(app, identifier)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "\(identifier) missing", file: file, line: line)
        // SwiftUI can publish a control's enabled state a frame after the keystroke that enables it: wait for it, and
        // when it never comes, print the screen's tree so the cause shows in the log.
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: button)
        guard XCTWaiter().wait(for: [enabled], timeout: 5) == .completed else {
            XCTFail("\(identifier) disabled\n\(app.debugDescription)", file: file, line: line)
            return
        }
        button.tap()
    }

    /// auth.phone: the landing's "Get Started" opens the phone form.
    @MainActor
    private func openPhoneForm(_ app: XCUIApplication) {
        XCTAssertTrue(element(app, "auth.phone").waitForExistence(timeout: 10))
        tap("auth.phone.getStarted", in: app)
        // The form's own container does not surface as an element inside auth.phone; its field does.
        XCTAssertTrue(app.textFields["auth.phone.field"].waitForExistence(timeout: 5), "the phone form")
    }

    // MARK: Sign-up → onboarding → home

    @MainActor
    func testSignUpThroughOnboardingLandsOnTheGroupsList() {
        let app = launch("signed-out")
        openPhoneForm(app)
        // The field starts with the region's calling code; the digits after it make "Next" available.
        type("5551234567", into: "auth.phone.field", in: app)
        tap("auth.phone.continue", in: app)

        XCTAssertTrue(element(app, "auth.code").waitForExistence(timeout: 5))
        type("123456", into: "auth.code.field", in: app)
        if element(app, "auth.code").exists, element(app, "auth.code.continue").exists, element(app, "auth.code.continue").isHittable {
            element(app, "auth.code.continue").tap()
        }

        XCTAssertTrue(element(app, "auth.agegate").waitForExistence(timeout: 5))
        type("01012000", into: "auth.agegate.field", in: app)
        let birthday = field(app, "auth.agegate.field")
        XCTAssertEqual((birthday.value as? String)?.filter(\.isNumber), "01012000", "every digit of the birthday reached the field")
        tap("auth.agegate.continue", in: app)

        XCTAssertTrue(element(app, "auth.profile").waitForExistence(timeout: 5))
        type("Ana", into: "auth.profile.field", in: app)
        tap("auth.profile.continue", in: app)

        // Step 2 (Retro's profile photo step): "Maybe Later".
        XCTAssertTrue(element(app, "auth.profile.photo").waitForExistence(timeout: 5))
        tap("auth.profile.photo.secondary", in: app)

        XCTAssertTrue(element(app, "onboarding.permission.notifications").waitForExistence(timeout: 5))
        tap("onboarding.notifications.continue", in: app)

        XCTAssertTrue(element(app, "onboarding.widget").waitForExistence(timeout: 5))
        tap("onboarding.widget.continue", in: app)

        XCTAssertTrue(element(app, "groups.list").waitForExistence(timeout: 5), "home after onboarding")
        XCTAssertTrue(element(app, "groups.list.empty.create").exists, "a new account has no groups yet")
    }

    @MainActor
    func testWrongCodeKeepsThePersonOnTheCodeStep() {
        let app = launch("signed-out")
        openPhoneForm(app)
        type("5551234567", into: "auth.phone.field", in: app)
        tap("auth.phone.continue", in: app)
        XCTAssertTrue(element(app, "auth.code").waitForExistence(timeout: 5))
        type("000000", into: "auth.code.field", in: app)
        if element(app, "auth.code.continue").isHittable { element(app, "auth.code.continue").tap() }
        XCTAssertFalse(element(app, "auth.agegate").waitForExistence(timeout: 2))
        XCTAssertTrue(element(app, "auth.code").exists)
    }

    // MARK: Create a group

    @MainActor
    func testCreateGroupOpensItsCreatedState() {
        let app = launch("signed-in")
        XCTAssertTrue(element(app, "groups.list").waitForExistence(timeout: 10))
        tap("groups.list.empty.create", in: app)

        XCTAssertTrue(element(app, "groups.create").waitForExistence(timeout: 5))
        // Step A: the type rows (Retro's templates); any row moves on to the cover and name. The rows are looked up inside
        // the sheet: the groups list under it shows the same template rows.
        let typeStep = element(app, "groups.create.type")
        XCTAssertTrue(typeStep.waitForExistence(timeout: 5))
        let friends = typeStep.buttons.matching(identifier: "groups.template.friends").firstMatch
        XCTAssertTrue(friends.waitForExistence(timeout: 5), "the Friends template row")
        friends.tap()
        XCTAssertTrue(element(app, "groups.create.name").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "groups.create.submit").isEnabled, "a name is required")
        type("Lima family", into: "groups.create.name", in: app)
        tap("groups.create.submit", in: app)

        XCTAssertTrue(element(app, "groups.screen").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "groups.screen.created").waitForExistence(timeout: 5), "a new group starts with the invite prompt")
        XCTAssertFalse(element(app, "groups.create").exists, "the sheet closed")

        // groups.invite: link sharing starts off; turning it on shows the link menu and the share targets.
        tap("groups.screen.invite", in: app)
        XCTAssertTrue(element(app, "groups.invite").waitForExistence(timeout: 5), "the invite sheet")
        tap("groups.invite.turnOn", in: app)
        XCTAssertTrue(element(app, "groups.invite.copy").waitForExistence(timeout: 5), "link on: QR Code · Copy Link · Message · Share")
        XCTAssertTrue(element(app, "groups.invite.reset").exists, "link on: the Reset link row")

        // The QR card (owner decision 17): over the sheet, closed by its close circle.
        tap("groups.invite.qr", in: app)
        XCTAssertTrue(element(app, "groups.invite.qr.card").waitForExistence(timeout: 5), "the QR card of the link")
        XCTAssertTrue(element(app, "groups.invite.qr.save").exists, "Save")
        XCTAssertTrue(element(app, "groups.invite.qr.share").exists, "Share")
        tap("groups.invite.qr.close", in: app)
        XCTAssertTrue(element(app, "groups.invite.copy").waitForExistence(timeout: 5), "back on the invite sheet")
    }

    // MARK: Settings

    @MainActor
    func testSettingsFromTheWallThenSignOut() {
        let app = launch("signed-in", ["-SocialFakes"])
        XCTAssertTrue(element(app, "groups.list").waitForExistence(timeout: 10))
        // The tab bar's me item (VoiceOver label, copy `groups.list.tab.me.accessibilityLabel`) → walls.mine.
        let me = app.buttons["Profile"].firstMatch
        XCTAssertTrue(me.waitForExistence(timeout: 5))
        me.tap()
        XCTAssertTrue(element(app, "walls.mine").waitForExistence(timeout: 10))
        // The gear capsule (copy `walls.mine.a11y.settings`) → settings.root.
        let gear = app.buttons["Settings"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: 5))
        gear.tap()
        XCTAssertTrue(element(app, "settings.root").waitForExistence(timeout: 10), "settings")

        let signOut = element(app, "settings.root.signOut")
        for _ in 0..<8 where !(signOut.exists && signOut.isHittable) {
            element(app, "settings.root").swipeUp()
        }
        XCTAssertTrue(signOut.isHittable, "Sign Out at the end of settings")
        signOut.tap()
        // The native confirmation (copy `settings.root.signOut.confirm`).
        let confirm = app.alerts.buttons["Yes, sign out"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Sign out?")
        confirm.tap()
        XCTAssertTrue(element(app, "auth.phone").waitForExistence(timeout: 10), "signed out: auth.phone")
        // The landing (A), not a form kept from the session that ended; its form starts empty (the calling code only).
        let getStarted = app.buttons["auth.phone.getStarted"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5), "the landing's Get started")
        getStarted.tap()
        let phone = app.textFields["auth.phone.field"]
        XCTAssertTrue(phone.waitForExistence(timeout: 5))
        let digits = ((phone.value as? String) ?? "").filter(\.isNumber)
        XCTAssertLessThanOrEqual(digits.count, 3, "no previous number in the field (only the calling code): \(digits)")
    }

    @MainActor
    func testGroupsListShowsTheMembersGroups() {
        let app = launch("with-groups")
        XCTAssertTrue(element(app, "groups.list").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "groups.list.row").waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "groups.list.row").count, 2)
    }
}
