#if SERVER_JOURNEY
import Foundation
import XCTest

/// The iOS app end to end against a real server (CI job "ios e2e", built with `-D SERVER_JOURNEY`): a Linux job runs the
/// local Supabase stack and the worker and exposes the API through a temporary tunnel; this test reads its address
/// (`JOLT_E2E_SUPABASE_URL`, `JOLT_E2E_SUPABASE_ANON_KEY`, passed to the runner as `TEST_RUNNER_…`) and launches the app
/// against it (DEBUG `ServerJourneyOverrides`). Nothing in the app is faked except the camera's stills
/// (`-capture-fake-camera`: the simulator has no camera) and the invite links' host (config/app.json `domain` is BLOCKED).
///
/// Journey, as two fictional people:
/// 1. Maya signs up with a test phone number (the stack's test OTP), passes the age gate, gives her name, skips the photo,
///    notification and widget steps; creates a group; turns link sharing on; takes a photo with the camera and sends it
///    to the group; sees it in the group, opens it in the viewer and reacts; sends a chat message; makes a plan.
/// 2. Theo, as another client of the same server (this test's own requests: test OTP sign-in, `join_group` with the
///    group's invite, `answer_plan`, `send_message`), joins, answers the plan Going and writes in the chat; Maya's app
///    shows his name under Going and his message in the chat (realtime).
/// 3. Maya opens settings and signs out.
/// Each step attaches a screenshot (the result bundle; CI exports them as the `ios-e2e` artifact). A step that fails is
/// recorded with its screenshot and the screen's tree, and the journey goes on where it can; the test fails at the end
/// with every problem listed.
final class ServerJourneyUITests: XCTestCase {
    private var stack: Stack!
    private var problems: [String] = []
    private var stepIndex = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        stack = try Stack.fromEnvironment()
    }

    @MainActor
    func testSignUpPostReactChatPlanWithAFriendOnTheRealServer() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-capture-fake-camera"]
        app.launchEnvironment = [
            "JOLT_E2E_SUPABASE_URL": stack.url.absoluteString,
            "JOLT_E2E_SUPABASE_ANON_KEY": stack.anonKey,
            "JOLT_E2E_INVITE_HOST": Self.inviteHost,
        ]
        app.launch()

        // ---- Maya signs up ----
        try signUp(app, Self.maya, who: "maya")
        try expect("groups.list", in: app, timeout: 30, "home after onboarding")
        step(app, "maya-groups-empty")

        // A group.
        try tap("groups.list.empty.create", in: app)
        let typeStep = element(app, "groups.create.type")
        try wait(typeStep, 10, "the group types")
        let family = typeStep.buttons.matching(identifier: "groups.template.family").firstMatch
        let template = family.waitForExistence(timeout: 3) ? family : typeStep.buttons.matching(identifier: "groups.template.friends").firstMatch
        try wait(template, 5, "a group type row")
        template.tap()
        try type(Self.groupName, into: "groups.create.name", in: app)
        step(app, "maya-create-name")
        try tap("groups.create.submit", in: app)
        try expect("groups.screen", in: app, timeout: 30, "the new group")
        try expect("groups.screen.created", in: app, timeout: 15, "a new group starts with the invite prompt")
        step(app, "maya-group-created")

        // Link sharing on (Theo joins with it).
        soft("invite-link", app) {
            try self.tap("groups.screen.invite", in: app)
            try self.expect("groups.invite", in: app, timeout: 15)
            try self.tap("groups.invite.turnOn", in: app)
            try self.expect("groups.invite.copy", in: app, timeout: 30, "link sharing on")
            self.step(app, "maya-invite-on")
            // The sheet's close circle (groups.invite.close.accessibilityLabel).
            let close = self.element(app, "groups.invite").buttons[Self.closeLabel].firstMatch
            try self.wait(close, 5, "the invite sheet's close circle")
            close.tap()
            try self.waitGone(self.element(app, "groups.invite"), 10, "the invite sheet closes")
        }

        // A photo: the group's add tile → the camera (fake stills) → send-to → posted.
        soft("photo", app) {
            let add = app.buttons[Self.addPhotoLabel].firstMatch
            try self.wait(add, 10, "the week strip's add tile")
            add.tap()
            let shutter = self.element(app, "camera.capture.shutter")
            try self.wait(shutter, 20, "the camera")
            self.step(app, "maya-camera")
            for _ in 0..<3 where !self.element(app, "camera.sendto").exists {
                shutter.tap()
                _ = self.element(app, "camera.sendto").waitForExistence(timeout: 5)
            }
            try self.expect("camera.sendto", in: app, timeout: 5, "send-to after the shutter")
            self.step(app, "maya-sendto")
            try self.tap("camera.sendto.send", in: app)
            try self.waitGone(self.element(app, "camera.sendto"), 90, "send-to closes once the post is made")
            try self.openGroup(app)
            try self.wait(self.mayaPhotoTile(app), 90, "Maya's photo in the group")
            self.step(app, "maya-group-with-post")
        }

        // The viewer and a reaction from the photo's menu.
        soft("viewer-reaction", app) {
            try self.ensureGroup(app)
            self.mayaPhotoTile(app).tap()
            try self.expect("photo.viewer", in: app, timeout: 20)
            let mine = self.labelled(app, beginningWith: "Your photo, ")
            try self.wait(mine, 20, "the viewer shows Maya's own photo")
            self.step(app, "maya-viewer")
            mine.press(forDuration: 1.0)
            let quick = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH %@", "React with ")).firstMatch
            try self.wait(quick, 10, "the quick reactions of the photo's menu")
            self.step(app, "maya-viewer-menu")
            quick.tap()
            try self.waitGone(quick, 10, "the photo's menu closes")
            let chip = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS[c] %@ AND NOT (label BEGINSWITH %@)", "fire", "React with")).firstMatch
            try self.wait(chip, 20, "the reaction chip")
            self.step(app, "maya-viewer-reacted")
            try self.tap("close", in: app)
            try self.expect("groups.screen", in: app, timeout: 10)
        }

        // Chat: a message.
        soft("chat", app) {
            try self.ensureGroup(app)
            try self.tap("groups.screen.chat", in: app)
            try self.expect("chat.thread", in: app, timeout: 20)
            let field = self.element(app, "chat.composer.field")
            try self.wait(field, 10, "the composer")
            field.tap()
            field.typeText(Self.mayaMessage)
            try self.tap("chat.composer.send", in: app)
            try self.wait(app.descendants(matching: .any)["You, \(Self.mayaMessage)"], 30, "the sent message in the thread")
            self.step(app, "maya-chat-sent")
            self.back(app)
            try self.expect("groups.screen", in: app, timeout: 10)
        }

        // A plan: the group's plan row → the sheet → the plan page, Maya under Going.
        soft("plan-create", app) {
            try self.ensureGroup(app)
            // The plan row's controls carry its container's identifier (groups.screen.plan): found by their labels.
            let create = app.buttons[Self.makeAPlanLabel].firstMatch
            try self.wait(create, 10, "the plan row's Make a Plan")
            for _ in 0..<3 where !create.isHittable { app.swipeUp() }
            create.tap()
            try self.expect("plans.create", in: app, timeout: 15)
            try self.type(Self.planTitle, into: "plans.create.name", in: app)
            try self.tap("plans.create.date", in: app)
            self.step(app, "maya-plan-create")
            try self.tap("plans.create.submit", in: app)
            try self.expect("plans.page", in: app, timeout: 30, "the new plan's page")
            try self.wait(self.going(app, containing: Self.maya.firstName), 20, "Maya under Going")
            self.step(app, "maya-plan")
        }

        // ---- Theo, another client of the same server ----
        soft("friend-joins", app) {
            let mayaSession = try self.stack.signIn(phone: Self.maya.phone)
            let invite = try self.stack.latestInvite(token: mayaSession.accessToken)
            let theo = try self.stack.signIn(phone: Self.theo.phone)
            try self.stack.setName(Self.theo.name, session: theo)
            try self.stack.rpc("join_group", ["p_token": invite.token], token: theo.accessToken)
            let plans = try self.stack.rpcRows("next_plans", ["p_group_id": invite.groupID], token: theo.accessToken)
            guard let plan = plans.first(where: { ($0["title"] as? String) == Self.planTitle }), let planID = plan["id"] as? String else {
                throw JourneyFailure("Theo does not see the plan in next_plans: \(plans)")
            }
            try self.stack.rpc("answer_plan", ["p_plan_id": planID, "p_answer": "going"], token: theo.accessToken)
            try self.stack.rpc("send_message", ["p_group_id": invite.groupID, "p_kind": "text", "p_body": Self.theoMessage], token: theo.accessToken)
        }

        // Maya's app: Theo under Going (the plan page refetches on the answer), his message in the chat.
        soft("friend-going", app) {
            if !self.element(app, "plans.page").exists {
                try self.ensureGroup(app)
                let open = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", Self.planTitle)).firstMatch
                try self.wait(open, 20, "the plan row")
                open.tap()
                try self.expect("plans.page", in: app, timeout: 20)
            }
            try self.wait(self.going(app, containing: Self.theo.firstName), 60, "Theo under Going")
            self.step(app, "maya-plan-theo-going")
            try self.tap("plans.page.back", in: app)
            try self.expect("groups.screen", in: app, timeout: 15)
        }
        soft("friend-message", app) {
            try self.ensureGroup(app)
            try self.tap("groups.screen.chat", in: app)
            try self.expect("chat.thread", in: app, timeout: 20)
            try self.wait(self.labelled(app, beginningWith: "\(Self.theo.firstName), \(Self.theoMessage)"), 60, "Theo's message in Maya's chat")
            self.step(app, "maya-chat-theo")
            self.back(app)
            try self.expect("groups.screen", in: app, timeout: 10)
        }

        // ---- Maya: settings → sign out ----
        closeOverlays(app)
        try openTab(app, Self.profileTab)
        try expect("walls.mine", in: app, timeout: 20)
        step(app, "maya-wall")
        let settings = app.buttons[Self.settingsLabel].firstMatch
        try wait(settings, 10, "the wall's settings capsule")
        settings.tap()
        try expect("settings.root", in: app, timeout: 15)
        let signOut = element(app, "settings.root.signOut")
        for _ in 0..<4 where !signOut.isHittable { element(app, "settings.root").swipeUp() }
        try tap("settings.root.signOut", in: app)
        let confirm = app.alerts.buttons[Self.signOutConfirm].firstMatch
        try wait(confirm, 10, "the sign-out confirmation")
        step(app, "maya-signout-confirm")
        confirm.tap()
        try expect("auth.phone", in: app, timeout: 30, "the landing after sign-out")
        step(app, "maya-signed-out")

        XCTAssertTrue(problems.isEmpty, "the journey finished with problems:\n" + problems.joined(separator: "\n"))
    }

    // MARK: Sign-up (auth.phone → auth.code → auth.agegate → auth.profile → onboarding)

    @MainActor
    private func signUp(_ app: XCUIApplication, _ person: Person, who: String) throws {
        try expect("auth.phone", in: app, timeout: 30, "the landing")
        step(app, "\(who)-landing")
        try tap("auth.phone.getStarted", in: app)
        try wait(app.textFields["auth.phone.field"], 10, "the phone form")
        // The field starts with the region's calling code (+1 on the US simulator).
        try type(person.nationalDigits, into: "auth.phone.field", in: app)
        step(app, "\(who)-phone")
        try tap("auth.phone.continue", in: app)

        try expect("auth.code", in: app, timeout: 30, "the code step (the stack sent no SMS: a test number)")
        try type(Self.testOTP, into: "auth.code.field", in: app)
        step(app, "\(who)-code")
        let next = element(app, "auth.code.continue")
        if element(app, "auth.code").exists, next.exists, next.isHittable { next.tap() }

        try expect("auth.agegate", in: app, timeout: 30)
        try type(Self.birthdayDigits, into: "auth.agegate.field", in: app)
        step(app, "\(who)-agegate")
        try tap("auth.agegate.continue", in: app)

        try expect("auth.profile", in: app, timeout: 30)
        try type(person.name, into: "auth.profile.field", in: app)
        step(app, "\(who)-name")
        try tap("auth.profile.continue", in: app)
        try expect("auth.profile.photo", in: app, timeout: 15)
        try tap("auth.profile.photo.secondary", in: app)

        // Notifications: "Maybe later" when the step offers it; else its button and the system's alert.
        try expect("onboarding.permission.notifications", in: app, timeout: 15)
        step(app, "\(who)-notifications")
        let later = app.buttons[Self.notificationsLater].firstMatch
        if later.exists {
            later.tap()
        } else {
            try tap("onboarding.notifications.continue", in: app)
            allowSystemAlert()
        }
        try expect("onboarding.widget", in: app, timeout: 15)
        step(app, "\(who)-widget")
        try tap("onboarding.widget.continue", in: app)
    }

    /// The system's permission alert (SpringBoard), answered "Allow" when it shows.
    @MainActor
    private func allowSystemAlert() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Allow"].firstMatch
        if allow.waitForExistence(timeout: 5) { allow.tap() }
    }

    // MARK: Navigation

    /// Home → the group's row → groups.screen.
    @MainActor
    private func openGroup(_ app: XCUIApplication) throws {
        if element(app, "groups.screen").exists { return }
        try openTab(app, Self.homeTab)
        try expect("groups.list", in: app, timeout: 15)
        let row = element(app, "groups.list.row")
        try wait(row, 20, "the group's row")
        row.tap()
        try expect("groups.screen", in: app, timeout: 15)
    }

    /// The group screen, from wherever a failed step left the app.
    @MainActor
    private func ensureGroup(_ app: XCUIApplication) throws {
        closeOverlays(app)
        try openGroup(app)
    }

    /// Back to the screen under whatever a failed step left open: a context menu (a tap above it), the viewer (its close
    /// circle), a plan page, a chat thread. A covered screen still "exists" to XCUITest, so this checks the covers.
    @MainActor
    private func closeOverlays(_ app: XCUIApplication) {
        for _ in 0..<6 {
            let menuRow = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "React with ")).firstMatch
            if menuRow.exists {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).tap()
                _ = waitGoneQuietly(menuRow, 5)
                continue
            }
            if element(app, "photo.viewer").exists {
                let close = element(app, "photo.viewer").buttons.matching(identifier: "close").firstMatch
                if close.exists { close.tap() } else { element(app, "close").tap() }
                _ = waitGoneQuietly(element(app, "photo.viewer"), 10)
                continue
            }
            if element(app, "plans.page.back").exists { element(app, "plans.page.back").tap(); continue }
            if element(app, "chat.thread").exists { back(app); continue }
            break
        }
    }

    @MainActor
    private func waitGoneQuietly(_ target: XCUIElement, _ timeout: TimeInterval) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: target)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    @MainActor
    private func openTab(_ app: XCUIApplication, _ label: String) throws {
        let tab = app.buttons[label].firstMatch
        try wait(tab, 15, "the \(label) tab")
        tab.tap()
    }

    /// The pushed page's back control (the header's chevron, labelled "Back").
    @MainActor
    private func back(_ app: XCUIApplication) {
        let back = app.buttons[Self.backLabel].firstMatch
        if back.waitForExistence(timeout: 5) { back.tap() }
    }

    // MARK: Finders

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func labelled(_ app: XCUIApplication, beginningWith prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// A week-strip tile of Maya's photo: a button labelled "<date>, photo by Maya" (groups.screen.photo.accessibilityLabel).
    private func mayaPhotoTile(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", photo by \(Self.maya.firstName)")).firstMatch
    }

    /// The plan page's Going list naming `firstName`.
    private func going(_ app: XCUIApplication, containing firstName: String) -> XCUIElement {
        let list = element(app, "plans.page.going")
        return list.exists && list.label.contains(firstName)
            ? list
            : app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "plans.page.going", firstName)).firstMatch
    }

    // MARK: Actions and waits

    @MainActor
    private func expect(_ identifier: String, in app: XCUIApplication, timeout: TimeInterval = 10, _ what: String = "") throws {
        try wait(element(app, identifier), timeout, what.isEmpty ? identifier : "\(identifier) (\(what))")
    }

    @MainActor
    private func wait(_ target: XCUIElement, _ timeout: TimeInterval, _ what: String) throws {
        guard target.waitForExistence(timeout: timeout) else {
            throw JourneyFailure("not on screen after \(Int(timeout)) s: \(what)")
        }
    }

    @MainActor
    private func waitGone(_ target: XCUIElement, _ timeout: TimeInterval, _ what: String) throws {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: target)
        guard XCTWaiter().wait(for: [gone], timeout: timeout) == .completed else {
            throw JourneyFailure("still on screen after \(Int(timeout)) s: \(what)")
        }
    }

    /// Taps the control carrying `identifier` (the button when there is one) once it is enabled.
    @MainActor
    private func tap(_ identifier: String, in app: XCUIApplication) throws {
        let candidate = app.buttons.matching(identifier: identifier).firstMatch
        let control = candidate.waitForExistence(timeout: 3) ? candidate : element(app, identifier)
        try wait(control, 10, identifier)
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: control)
        guard XCTWaiter().wait(for: [enabled], timeout: 15) == .completed else {
            throw JourneyFailure("\(identifier) stayed disabled")
        }
        control.tap()
    }

    /// Types one key at a time (the phone and birthday fields reformat as they are typed), then closes the system's
    /// one-time keyboard tip if it showed (AccountFlowUITests, run 78).
    @MainActor
    private func type(_ text: String, into identifier: String, in app: XCUIApplication) throws {
        let textField = app.textFields[identifier]
        let target = textField.exists ? textField : element(app, identifier)
        try wait(target, 10, identifier)
        target.tap()
        for character in text {
            target.typeText(String(character))
        }
        let tip = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "sliding your finger")).firstMatch
        if tip.exists, app.buttons["Continue"].exists { app.buttons["Continue"].tap() }
    }

    // MARK: Evidence and problems

    /// A screenshot of the step, kept in the result bundle (named `<nn>-<step>`).
    @MainActor
    private func step(_ app: XCUIApplication, _ name: String) {
        stepIndex += 1
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = String(format: "%02d-%@", stepIndex, name)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Runs `block`; a failure is recorded (a test failure in the log at once, the screenshot and the screen's tree) and
    /// the journey goes on.
    @MainActor
    private func soft(_ name: String, _ app: XCUIApplication, _ block: () throws -> Void) {
        do {
            try block()
        } catch {
            XCTFail("\(name): \(error)")
            problems.append("\(name): \(error)")
            step(app, "problem-\(name)")
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "problem-\(name)-tree"
            tree.lifetime = .keepAlways
            add(tree)
        }
    }

    // MARK: The people and the data

    private struct Person {
        let phone: String
        let nationalDigits: String
        let name: String
        var firstName: String { String(name.split(separator: " ").first ?? "") }
    }

    // Test numbers (NANP 555-01xx, fictional) and their code: the CI stack's [auth.sms.test_otp] (.github/workflows/ci.yml).
    private static let maya = Person(phone: "+12015550111", nationalDigits: "2015550111", name: "Maya Reyes")
    private static let theo = Person(phone: "+12015550112", nationalDigits: "2015550112", name: "Theo Park")
    private static let testOTP = "123456"
    /// March 14, 1990, as the US simulator's age gate takes it (month, day, year).
    private static let birthdayDigits = "03141990"
    private static let groupName = "Reyes family"
    private static let mayaMessage = "See you all on Sunday"
    private static let theoMessage = "Count me in for lunch"
    private static let planTitle = "Sunday lunch at Grandma's"
    /// Invite links' host for the run (RFC 6761 `.test`).
    private static let inviteHost = "invite.e2e.test"

    // The app's English copy the journey reads (design/copy: groups.list.tab.*, groups.screen.week.add.accessibilityLabel,
    // walls.mine.a11y.settings, settings.root.signOut.confirm, groups.screen.back.accessibilityLabel,
    // groups.invite.close.accessibilityLabel, plans.create.entry, onboarding.permission.notifications.skip).
    private static let homeTab = "Home"
    private static let profileTab = "Profile"
    private static let addPhotoLabel = "Add a photo"
    private static let settingsLabel = "Settings"
    private static let signOutConfirm = "Yes, sign out"
    private static let backLabel = "Back"
    private static let closeLabel = "Close"
    private static let makeAPlanLabel = "Make a Plan"
    private static let notificationsLater = "Maybe later"
}

private struct JourneyFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// The test stack, reached directly by this test as another client of the server (Theo): Supabase Auth's phone OTP
/// (the stack's test numbers send no SMS), PostgREST tables and RPCs, with the anon key.
/// One HTTP answer, filled on URLSession's queue and read after its semaphore.
private final class Reply: @unchecked Sendable {
    var data: Data?
    var status = 0
    var error: Error?
}

private struct Stack {
    let url: URL
    let anonKey: String

    struct Session {
        let accessToken: String
        let userID: String
    }

    struct Invite {
        let token: String
        let groupID: String
    }

    static func fromEnvironment() throws -> Stack {
        let environment = ProcessInfo.processInfo.environment
        guard let text = environment["JOLT_E2E_SUPABASE_URL"], let url = URL(string: text), url.scheme != nil,
              let key = environment["JOLT_E2E_SUPABASE_ANON_KEY"], !key.isEmpty else {
            throw JourneyFailure("JOLT_E2E_SUPABASE_URL / JOLT_E2E_SUPABASE_ANON_KEY are not set (TEST_RUNNER_… in CI): no server to run against")
        }
        return Stack(url: url, anonKey: key)
    }

    /// Phone sign-in with the test OTP: `POST /auth/v1/otp`, then `POST /auth/v1/verify`.
    func signIn(phone: String) throws -> Session {
        _ = try request("POST", "/auth/v1/otp", body: ["phone": phone], token: nil)
        let data = try request("POST", "/auth/v1/verify", body: ["type": "sms", "phone": phone, "token": "123456"], token: nil)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = object["access_token"] as? String,
              let user = object["user"] as? [String: Any], let id = user["id"] as? String else {
            throw JourneyFailure("verify answered without a session: \(String(decoding: data, as: UTF8.self))")
        }
        return Session(accessToken: token, userID: id)
    }

    func setName(_ name: String, session: Session) throws {
        _ = try request("PATCH", "/rest/v1/profiles?id=eq.\(session.userID)", body: ["display_name": name], token: session.accessToken)
    }

    /// The newest live invite readable by the caller (a member of the group).
    func latestInvite(token: String) throws -> Invite {
        let data = try request("GET", "/rest/v1/group_invites?select=token,group_id&revoked_at=is.null&order=created_at.desc&limit=1", body: nil, token: token)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], let row = rows.first,
              let invite = row["token"] as? String, let group = row["group_id"] as? String else {
            throw JourneyFailure("no live invite: \(String(decoding: data, as: UTF8.self))")
        }
        return Invite(token: invite, groupID: group)
    }

    @discardableResult
    func rpc(_ function: String, _ arguments: [String: Any], token: String) throws -> Data {
        try request("POST", "/rest/v1/rpc/\(function)", body: arguments, token: token)
    }

    func rpcRows(_ function: String, _ arguments: [String: Any], token: String) throws -> [[String: Any]] {
        let data = try rpc(function, arguments, token: token)
        return (try JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }

    private func request(_ method: String, _ path: String, body: [String: Any]?, token: String?) throws -> Data {
        var request = URLRequest(url: URL(string: url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path)!)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token ?? anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        // The test methods are synchronous: wait for the answer (URLSession calls back on its own queue).
        let semaphore = DispatchSemaphore(value: 0)
        let reply = Reply()
        URLSession.shared.dataTask(with: request) { data, response, error in
            reply.data = data
            reply.status = (response as? HTTPURLResponse)?.statusCode ?? 0
            reply.error = error
            semaphore.signal()
        }.resume()
        semaphore.wait()
        if let error = reply.error { throw JourneyFailure("\(method) \(path): \(error)") }
        let status = reply.status
        let data = reply.data ?? Data()
        guard (200..<300).contains(status) else {
            throw JourneyFailure("\(method) \(path): HTTP \(status) \(String(decoding: data, as: UTF8.self))")
        }
        return data
    }
}
#endif
