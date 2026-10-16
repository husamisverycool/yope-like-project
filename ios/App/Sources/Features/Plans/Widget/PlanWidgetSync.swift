// Surface: widget.countdown — the app's half: it writes the snapshot of `next_plans()` (title, `local_date`,
// `starts_at`, group name, the downloaded cover) to the App Group store the widget reads, as the group-photo widget's
// data gets there, on every foreground and after the member's own plan changes; then reloads the countdown widget
// (design/surfaces/widget.countdown.md "Data & actions").
import AppData
import AppModels
import Foundation
import WidgetKit

@MainActor
final class PlanWidgetSync {
    static let shared = PlanWidgetSync()

    private var running: Task<Void, Never>?
    private var again = false

    /// Rewrites the snapshot (coalesced: a request while one runs schedules one more run).
    func refresh() {
        guard running == nil else {
            again = true
            return
        }
        running = Task { [weak self] in
            await self?.write()
            self?.finished()
        }
    }

    private func finished() {
        running = nil
        if again {
            again = false
            refresh()
        }
    }

    private func write() async {
        let store = AppEnvironment.shared.widgetStore
        let data = PlansServices.shared.plans
        guard await data.currentUser() != nil,
              let plans = try? await data.nextPlans(groupID: nil),
              let groups = try? await data.myGroups() else { return }
        let names = Dictionary(groups.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let resolver = AppEnvironment.shared.accountDependencies.storageURLResolver
        var snapshots: [PlanWidgetSnapshot] = []
        for plan in plans {
            var cover: String?
            if let path = plan.coverPath {
                let name = Self.coverFileName(planID: plan.id, path: path)
                if FileManager.default.fileExists(atPath: store.plansDirectory.appendingPathComponent(name).path) {
                    cover = name
                } else if let bytes = await Self.download(path, resolver: resolver), (try? store.writePlanFile(bytes, fileName: name)) != nil {
                    cover = name
                }
            }
            snapshots.append(PlanWidgetSnapshot(
                planID: plan.id.rawValue, groupID: plan.groupID.rawValue, groupName: names[plan.groupID] ?? "",
                title: plan.title, localDate: plan.localDate.description, startsAt: plan.startsAt, coverFileName: cover
            ))
        }
        try? store.savePlans(snapshots)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.planCountdown)
    }

    /// One file per cover upload: a new cover (a new storage object) gets a new name, and `savePlans` prunes the old file.
    static func coverFileName(planID: PlanID, path: String) -> String {
        let object = (path as NSString).lastPathComponent.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." }
        return planID.rawValue + "-" + object // provenance-ok: file name built from ids
    }

    private static func download(_ path: String, resolver: StorageURLResolver) async -> Data? {
        guard let url = try? await resolver(path) else { return nil }
        if url.isFileURL { return try? Data(contentsOf: url) }
        return try? await URLSession.shared.data(from: url).0
    }
}
