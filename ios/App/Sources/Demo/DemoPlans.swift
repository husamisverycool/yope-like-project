// The Jolt demo (`DemoMode`): plans, the weekly question and the developing tile in the demo world (`SocialDemo`).
// "roommates" has an upcoming plan this Saturday evening, made by Ana — Ana and Ben going, Cleo maybe, Sam (the demo
// member) not answered yet, so answering on the plan page changes it; the weekly question is on there with Cleo's
// photo as its one answer; and a photo is developing for tomorrow's 09:00. "climbing" (Sam is its admin) has the
// question off, so its group settings show the switch.
#if DEBUG
import AppData
import AppModels
import Foundation

enum DemoPlans {
    static let dinnerID = PlanID("00000000-0000-4000-8000-00000000f101")
    static let questionID = GroupQuestionID("00000000-0000-4000-8000-00000000f201")
    /// The question the demo's group asks this week (`app_config.weekly_question_keys` names q01 first).
    static let questionKey = "question.weekly.q01" // provenance-ok: copy key

    /// Saturday 19:30 of the demo week — next week's when this week's has passed (the plan stays upcoming).
    static var dinnerStart: Date {
        let world = SocialDemo.self
        let saturday = world.monday.addingTimeInterval(5 * world.day + 19.5 * world.hour) // provenance-ok: demo data (Saturday 19:30)
        let now = DemoMode.isOn ? DemoMode.launchDate : world.at(4 * world.day)
        return saturday > now ? saturday : saturday.addingTimeInterval(7 * world.day)
    }

    /// The first 09:00 after the demo's "now" in the device's zone (camera.overnight's reveal rule).
    static var nextReveal: Date {
        let now = DemoMode.isOn ? DemoMode.launchDate : SocialDemo.at(4 * SocialDemo.day)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let nine = DateComponents(hour: 9, minute: 0) // provenance-ok: demo data (the 09:00 reveal)
        return calendar.nextDate(after: now, matching: nine, matchingPolicy: .nextTime) ?? now.addingTimeInterval(SocialDemo.day)
    }

    static func makeData() -> FakePlansData {
        let world = SocialDemo.self
        let data = FakePlansData(me: world.me)
        let roommates = world.group(world.groupID, name: "roommates", createdBy: world.ana) // provenance-ok: demo data
        let climbing = world.group(world.otherGroupID, name: "climbing", createdBy: world.me) // provenance-ok: demo data
        let start = dinnerStart
        let made = world.at(1 * world.hour)
        let dinner = Plan(
            id: dinnerID, groupID: world.groupID, createdBy: world.ana,
            title: "Dinner at ours", startsAt: start, allDay: false, // provenance-ok: fixture data
            localDate: LocalDate(start, in: roommates.resolvedTimeZone),
            place: "Our kitchen", note: "Bring something sweet", // provenance-ok: fixture data
            coverPath: "fake/photo/01", createdAt: made, updatedAt: made // provenance-ok: demo storage path
        )
        let answer = { (user: UserID, kind: PlanAnswerKind, minutes: Double) in
            PlanAnswer(planID: dinnerID, userID: user, groupID: world.groupID, answer: kind, answeredAt: made.addingTimeInterval(minutes * 60))
        }
        let answerPhoto = world.posts.filter { $0.id == world.p4 }
        data.update { state in
            state.groups = [roommates, climbing]
            state.members[world.groupID] = [
                world.member(world.ana, in: world.groupID, role: .admin), world.member(world.me, in: world.groupID),
                world.member(world.ben, in: world.groupID), world.member(world.cleo, in: world.groupID),
            ]
            state.members[world.otherGroupID] = [
                world.member(world.me, in: world.otherGroupID, role: .admin), world.member(world.ben, in: world.otherGroupID),
            ]
            state.plans[dinnerID] = dinner
            state.answers = [answer(world.ana, .going, 0), answer(world.ben, .going, 20), answer(world.cleo, .maybe, 45)]
            state.questions[world.groupID] = GroupQuestion(id: questionID, questionKey: questionKey, weekStart: world.thisWeek, hiddenByMe: false)
            state.questionAnswers[questionID] = answerPhoto
            state.weeklyQuestion = [world.groupID: true, world.otherGroupID: false]
            state.developing[world.groupID] = OvernightStatus(developing: true, revealAt: nextReveal)
            // A photo sent from the demo camera joins the account data's feed (`DemoSentPosts`): the answer is found there.
            state.postLookup = { mediaID, groupID in
                await MainActor.run {
                    let account = AppEnvironment.shared.accountDependencies.data as? InMemoryAccountData
                    return account?.postsByGroup[groupID]?.first { $0.post.mediaID == mediaID }
                }
            }
        }
        return data
    }
}
#endif
