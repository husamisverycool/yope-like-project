// Account group — sign-up view models: auth.phone (PhoneNumberInput, PhoneModel), auth.code (CodeModel),
// auth.agegate (BirthdayEntry, AgeGateModel), auth.profile (ProfileModel) and the AuthFailure mapping.
@testable import App
import AppData
import AppModels
import DesignSystem
import XCTest

@MainActor
final class AccountAuthTests: XCTestCase {
    // MARK: PhoneNumberInput

    func testPhoneFieldStartsWithTheRegionsCallingCode() {
        XCTAssertEqual(PhoneNumberInput.initialText(region: "US"), "+1")
        XCTAssertEqual(PhoneNumberInput.initialText(region: "pt"), "+351")
        XCTAssertEqual(PhoneNumberInput.initialText(region: "GB"), "+44")
        XCTAssertEqual(PhoneNumberInput.initialText(region: nil), "+")
        XCTAssertEqual(PhoneNumberInput.initialText(region: "ZZ"), "+")
    }

    func testContinueNeedsDigitsAfterTheCallingCode() {
        XCTAssertFalse(PhoneNumberInput.hasSubscriberDigits("+1"))
        XCTAssertFalse(PhoneNumberInput.hasSubscriberDigits("+351"))
        XCTAssertTrue(PhoneNumberInput.hasSubscriberDigits("+3519"))
        XCTAssertTrue(PhoneNumberInput.hasSubscriberDigits("+1 555"))
        XCTAssertFalse(PhoneNumberInput.hasSubscriberDigits("+"))
        XCTAssertEqual(PhoneNumberInput.callingCode(of: "+44 7700 900123"), "44")
        XCTAssertEqual(PhoneNumberInput.callingCode(of: "+1 (555) 123"), "1")
    }

    func testNumbersAreNormalisedToE164() {
        XCTAssertEqual(PhoneNumberInput.normalized("+1 (555) 123-4567"), "+15551234567")
        XCTAssertEqual(PhoneNumberInput.normalized(" +351 912 345 678 "), "+351912345678")
        XCTAssertEqual(PhoneNumberInput.normalized("44.7700.900123"), "+447700900123")
        XCTAssertNil(PhoneNumberInput.normalized("+0123456"), "no leading zero")
        XCTAssertNil(PhoneNumberInput.normalized("+1"), "too short")
        XCTAssertNil(PhoneNumberInput.normalized("+1234567890123456"), "too long")
        XCTAssertNil(PhoneNumberInput.normalized("+1 555 abc"))
        XCTAssertNil(PhoneNumberInput.normalized("+1+555"))
        XCTAssertEqual(PhoneNumberInput.digits(of: "+1 (555) 12"), "155512")
    }

    func testFlagFollowsTheTypedCallingCode() {
        XCTAssertEqual(PhoneNumberInput.flag(for: "PT"), "\u{1F1F5}\u{1F1F9}")
        XCTAssertEqual(PhoneNumberInput.flag(for: "us"), "\u{1F1FA}\u{1F1F8}")
        XCTAssertEqual(PhoneNumberInput.flag(for: "1A"), "")
        XCTAssertEqual(PhoneNumberInput.region(of: "+351 912", preferring: [nil, "US"]), "PT")
        XCTAssertEqual(PhoneNumberInput.region(of: "+1 555", preferring: [nil, "CA"]), "CA", "a shared code keeps the device region")
        XCTAssertEqual(PhoneNumberInput.region(of: "+1 555", preferring: [nil, "PT"]), "US", "else the code's main region")
        XCTAssertEqual(PhoneNumberInput.region(of: "+44", preferring: ["JE", "PT"]), "JE", "the picked country wins")
        XCTAssertNil(PhoneNumberInput.region(of: "+", preferring: ["US"]))
    }

    func testChoosingACountryReplacesOnlyTheCallingCode() {
        XCTAssertEqual(PhoneNumberInput.replacingCallingCode(in: "+1 555 123", with: "351"), "+351 555 123")
        XCTAssertEqual(PhoneNumberInput.replacingCallingCode(in: "+1555123", with: "44"), "+44 555123")
        XCTAssertEqual(PhoneNumberInput.replacingCallingCode(in: "+1", with: "44"), "+44")
        XCTAssertEqual(PhoneNumberInput.replacingCallingCode(in: "+", with: "44"), "+44")

        let model = PhoneModel(data: InMemoryAccountData(), deviceRegion: "US")
        XCTAssertEqual(model.phone, "+1")
        XCTAssertEqual(model.flagRegion, "US")
        model.phone = "+1 555 123 4567"
        model.selectCountry("CA")
        XCTAssertEqual(model.phone, "+1 555 123 4567")
        XCTAssertEqual(model.flagRegion, "CA", "same code: the chosen country's flag")
        model.selectCountry("pt")
        XCTAssertEqual(model.phone, "+351 555 123 4567")
        XCTAssertEqual(model.flagRegion, "PT")
    }

    func testCountryListIsSortedAndComplete() {
        let countries = PhoneNumberInput.countries(locale: Locale(identifier: "en_US"))
        XCTAssertTrue(countries.contains { $0.region == "PT" && $0.callingCode == "351" })
        XCTAssertEqual(countries.map(\.name), countries.map(\.name).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
        XCTAssertGreaterThan(countries.count, 200)
    }

    // MARK: AuthFailure

    func testSendErrorsMapToTheAuthPhoneStates() {
        XCTAssertNil(AuthFailure.sending(DataError.offline))
        XCTAssertEqual(AuthFailure.sending(DataError.auth(.invalidPhone)), .invalidNumber)
        XCTAssertEqual(AuthFailure.sending(DataError.auth(.rateLimited)), .rateLimited)
        XCTAssertEqual(AuthFailure.sending(DataError.http(status: 429)), .rateLimited)
        XCTAssertEqual(AuthFailure.sending(DataError.auth(.smsSendFailed)), .sendFailed)
        XCTAssertEqual(AuthFailure.sending(DataError.http(status: 503)), .sendFailed)
    }

    func testVerifyErrorsMapToTheAuthCodeStates() {
        XCTAssertNil(AuthFailure.verifying(DataError.offline, codeAge: 10))
        XCTAssertEqual(AuthFailure.verifying(DataError.auth(.invalidOTP), codeAge: 10), .wrongCode)
        XCTAssertEqual(AuthFailure.verifying(DataError.auth(.invalidOTP), codeAge: AuthFailure.codeLifetime), .expired)
        XCTAssertEqual(AuthFailure.verifying(DataError.auth(.rateLimited), codeAge: 10), .tooManyTries)
        XCTAssertEqual(AuthFailure.verifying(DataError.http(status: 429), codeAge: 10), .tooManyTries)
        XCTAssertEqual(AuthFailure.wrongCode.message, Copy.authCodeErrorWrong)
        XCTAssertEqual(AuthFailure.invalidNumber.message, Copy.authPhoneErrorInvalidNumber)
    }

    // MARK: auth.phone

    func testPhoneSendsTheNormalisedNumber() async {
        let data = InMemoryAccountData()
        let model = PhoneModel(data: data, phone: "+1 (555) 123-4567")
        XCTAssertTrue(model.canContinue)
        let sent = await model.send()
        XCTAssertEqual(sent, "+15551234567")
        XCTAssertEqual(data.sentCodes, ["+15551234567"])
        XCTAssertEqual(model.successCount, 1)
        XCTAssertNil(model.failure)
        XCTAssertFalse(model.isSending)
    }

    func testPhoneContinueIsDisabledUntilDigitsFollowTheCode() async {
        let data = InMemoryAccountData()
        let model = PhoneModel(data: data, phone: "+1")
        XCTAssertFalse(model.canContinue)
        let sent = await model.send()
        XCTAssertNil(sent)
        XCTAssertTrue(data.calls.isEmpty)
    }

    func testPhoneInvalidNumberNeverReachesTheServer() async {
        let data = InMemoryAccountData()
        let model = PhoneModel(data: data, phone: "+0 12")
        let sent = await model.send()
        XCTAssertNil(sent)
        XCTAssertEqual(model.failure, .invalidNumber)
        XCTAssertEqual(model.errorCount, 1)
        XCTAssertTrue(data.calls.isEmpty)
    }

    func testPhoneRateLimitAndOffline() async {
        let data = InMemoryAccountData()
        data.failures["sendCode"] = .auth(.rateLimited)
        let model = PhoneModel(data: data, phone: "+15551234567")
        _ = await model.send()
        XCTAssertEqual(model.failure, .rateLimited)

        data.failures["sendCode"] = .offline
        _ = await model.send()
        XCTAssertTrue(model.failedOffline)
        model.retryAfterOffline()
        XCTAssertFalse(model.failedOffline)
    }

    // MARK: auth.code

    func testCodeVerifiesAndHandsTheUserToTheSession() async {
        let data = InMemoryAccountData()
        let model = CodeModel(phone: "+15551234567", data: data, sleep: { _ in })
        model.setCode("123 456")
        XCTAssertEqual(model.code, "123456", "digits only (AutoFill / paste)")
        var verified: UserID?
        await model.verify { verified = $0 }
        XCTAssertNotNil(verified)
        XCTAssertEqual(model.successCount, 1)
    }

    func testWrongCodeClearsTheFieldAndExpiredCodeIsNamed() async {
        let data = InMemoryAccountData()
        let sentAt = Date(timeIntervalSince1970: 0)
        var now = sentAt.addingTimeInterval(30)
        let model = CodeModel(phone: "+15551234567", data: data, codeSentAt: sentAt, now: { now }, sleep: { _ in })
        model.setCode("000000")
        await model.verify { _ in XCTFail("not verified") }
        XCTAssertEqual(model.failure, .wrongCode)
        XCTAssertEqual(model.code, "")
        XCTAssertEqual(model.errorCount, 1)

        now = sentAt.addingTimeInterval(AuthFailure.codeLifetime + 1)
        model.setCode("000000")
        await model.verify { _ in }
        XCTAssertEqual(model.failure, .expired)
    }

    func testResendIsLockedUntilTheTokenDurationPasses() async {
        let data = InMemoryAccountData()
        let sentAt = Date(timeIntervalSince1970: 0)
        var now = sentAt
        let model = CodeModel(phone: "+15551234567", data: data, codeSentAt: sentAt, now: { now }, sleep: { _ in
            try? await Task.sleep(nanoseconds: 60_000_000_000)
        })
        model.startResendLock()
        XCTAssertTrue(model.isResendLocked)
        let refused = await model.resend()
        XCTAssertFalse(refused)
        XCTAssertTrue(data.sentCodes.isEmpty)

        now = sentAt.addingTimeInterval(Tokens.Durations.authCodeDurationResendLock + 1)
        model.startResendLock()
        XCTAssertFalse(model.isResendLocked, "auth.code.duration.resendLock elapsed")
        let resent = await model.resend()
        XCTAssertTrue(resent)
        XCTAssertEqual(data.sentCodes, ["+15551234567"])
        XCTAssertTrue(model.isResendLocked, "locked again after a resend")
    }

    func testResendLockReleasesAfterTheSleep() async {
        let data = InMemoryAccountData()
        let model = CodeModel(phone: "+15551234567", data: data, codeSentAt: Date(), sleep: { _ in await Task.yield() })
        model.startResendLock()
        await waitUntil { !model.isResendLocked }
    }

    // MARK: auth.agegate

    func testBirthdayEntryFollowsTheLocaleOrder() {
        let us = BirthdayEntry(pattern: "MM/dd/y")
        XCTAssertEqual(us.placeholderFormat, "mm/dd/yyyy")
        XCTAssertEqual(us.text(forDigits: "0526"), "05/26")
        XCTAssertEqual(us.text(forDigits: "05262000"), "05/26/2000")
        XCTAssertEqual(us.date(from: "05/26/2000"), LocalDate(year: 2000, month: 5, day: 26))
        XCTAssertNil(us.date(from: "02/30/2000"), "not a calendar date")
        XCTAssertFalse(us.isComplete("05/26/20"))

        let german = BirthdayEntry(pattern: "dd.MM.y")
        XCTAssertEqual(german.text(forDigits: "26052000"), "26.05.2000")
        XCTAssertEqual(german.date(from: "26.05.2000"), LocalDate(year: 2000, month: 5, day: 26))

        let japanese = BirthdayEntry(pattern: "y/MM/dd")
        XCTAssertEqual(japanese.text(forDigits: "20000526"), "2000/05/26")
    }

    func testBirthdayEntryDeletingASeparatorDeletesTheDigitBeforeIt() {
        let entry = BirthdayEntry(pattern: "MM/dd/y")
        XCTAssertEqual(entry.edit(from: "05/", to: "05"), "0")
        XCTAssertEqual(entry.edit(from: "05/2", to: "05/"), "05")
        XCTAssertEqual(entry.edit(from: "", to: "05262000999"), "05/26/2000", "extra digits are dropped")
    }

    func testBirthdayEntryUsesTheLocalesDateTemplate() {
        XCTAssertEqual(BirthdayEntry(locale: Locale(identifier: "en_US")).placeholderFormat, "mm/dd/yyyy")
        XCTAssertEqual(BirthdayEntry(locale: Locale(identifier: "de_DE")).placeholderFormat, "dd.mm.yyyy")
    }

    func testAgeGateConfirmsAndOptsIn() async {
        let fixture = AccountFixture()
        let model = AgeGateModel(data: fixture.data, entry: BirthdayEntry(pattern: "MM/dd/y"))
        model.setText("05262000")
        XCTAssertEqual(model.text, "05/26/2000")
        XCTAssertTrue(model.canContinue)
        model.optIn = true
        let outcome = await model.confirm()
        XCTAssertEqual(outcome, .confirmed)
        XCTAssertEqual(fixture.data.calls.suffix(2), ["confirmAge", "setBirthday"])
        XCTAssertEqual(fixture.data.privateProfile?.birthdayOptIn, true)
    }

    func testAgeGateWithoutOptInDoesNotStoreTheBirthday() async {
        let fixture = AccountFixture()
        let model = AgeGateModel(data: fixture.data, entry: BirthdayEntry(pattern: "MM/dd/y"))
        model.setText("05262000")
        _ = await model.confirm()
        XCTAssertFalse(fixture.data.calls.contains("setBirthday"))
    }

    func testAgeGateStates() async {
        let fixture = AccountFixture()
        let model = AgeGateModel(data: fixture.data, entry: BirthdayEntry(pattern: "MM/dd/y"))

        model.setText("02302000")
        var outcome = await model.confirm()
        XCTAssertEqual(outcome, .stay)
        XCTAssertTrue(model.invalidDate, "not a calendar date")
        XCTAssertFalse(fixture.data.calls.contains("confirmAge"))

        model.setText("05262015")
        fixture.data.failures["confirmAge"] = .api(.underMinimumAge)
        outcome = await model.confirm()
        XCTAssertEqual(outcome, .underAge(minAge: 13))

        fixture.data.failures["confirmAge"] = .api(.ageGateNotConfigured)
        outcome = await model.confirm()
        XCTAssertEqual(outcome, .stay)
        XCTAssertEqual(model.phase, .notConfigured)
        model.retry()
        XCTAssertEqual(model.phase, .form)

        fixture.data.failures["confirmAge"] = .offline
        _ = await model.confirm()
        XCTAssertEqual(model.phase, .offline)
    }

    // MARK: auth.profile

    func testProfileSavesTheTrimmedName() async {
        let fixture = AccountFixture()
        let model = ProfileModel(data: fixture.data)
        XCTAssertFalse(model.canContinue)
        model.setName("  Ana  ")
        XCTAssertTrue(model.canContinue)
        let saved = await model.save()
        XCTAssertTrue(saved)
        XCTAssertEqual(fixture.data.profilesByID[fixture.me.id]?.displayName, "Ana")
        XCTAssertFalse(fixture.data.calls.contains("uploadAvatar"), "no photo picked")
    }

    func testProfileNameIsCappedAndFailuresAreReported() async {
        let fixture = AccountFixture()
        let model = ProfileModel(data: fixture.data)
        model.setName(String(repeating: "a", count: 200))
        XCTAssertEqual(model.name.count, ProfileModel.maxNameLength)

        fixture.data.failures["updateProfile"] = .http(status: 500)
        var saved = await model.save()
        XCTAssertFalse(saved)
        XCTAssertEqual(model.failureMessage, Copy.authProfileErrorSave)

        fixture.data.failures["updateProfile"] = .offline
        saved = await model.save()
        XCTAssertFalse(saved)
        XCTAssertEqual(model.phase, .offline)
        model.retry()
        XCTAssertEqual(model.phase, .form)
    }
}
