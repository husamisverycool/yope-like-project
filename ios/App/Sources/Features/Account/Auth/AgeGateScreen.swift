// Surface: auth.agegate — the app's age step (the form is Shared/AgeGateForm.swift, shared with the App Clip). Visual
// reference: Retro sign-up (references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png) and Retro's switch row
// (references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png); design/surfaces/auth.agegate.md.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

/// auth.agegate in the app's sign-up stack: confirmed → auth.profile; under age → the remembered refusal.
struct AgeGateScreen: View {
    @State private var model: AgeGateModel
    @Environment(AccountDependencies.self) private var dependencies

    init(model: AgeGateModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        AgeGateForm(
            model: model,
            network: dependencies.network,
            onConfirmed: { dependencies.session.ageConfirmed() },
            onUnderAge: { minAge in await dependencies.session.refuseUnderAge(minAge: minAge) }
        )
    }
}
