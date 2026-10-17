import SwiftUI
import WidgetKit

@main
struct AppWidgets: WidgetBundle {
    var body: some Widget {
        GroupPhotoWidget()
        FriendPhotoWidget()
        MemoriesWidget()
        GroupLockWidget()
        PlanCountdownWidget()
        DailyInvitationLiveActivity()
        if #available(iOS 18.0, *) {
            CameraControl()
        }
    }
}
