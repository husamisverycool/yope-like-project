// Surface: invite.appclip — reference app: Partiful + Apple HIG (App Clips).
// Reference images: listed in design/surfaces/invite.appclip.md (docs/SURFACES.md).
// Container only: the screens pass builds this surface from its spec, with Tokens.* / Copy.*.
import SwiftUI

/// Invite link opened inside the installed app: the same preview as the App Clip, then join.
struct InviteScreen: View {
    let token: String

    var body: some View {
        ScreenContainer(surface: "invite.appclip")
    }
}
