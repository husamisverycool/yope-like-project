// Account group — copy chosen by the group's kind (`group_kind`: friends · family · roommates · custom), which takes
// the role of Retro's album templates (MERGE RA-23).
import AppData
import DesignSystem
import Foundation

enum GroupKindCopy {
    /// The kinds in `group_kind` order (the template rows of groups.list and groups.create step A).
    static let kinds: [GroupKind] = [.friends, .family, .roommates, .custom]

    /// `groups.create.type.*`
    static func title(_ kind: GroupKind?) -> String {
        switch kind {
        case .family: return Copy.groupsCreateTypeFamily
        case .roommates: return Copy.groupsCreateTypeRoommates
        case .custom, .unknown: return Copy.groupsCreateTypeCustom
        case .friends, .none: return Copy.groupsCreateTypeFriends
        }
    }

    /// `groups.create.type.*.detail`
    static func detail(_ kind: GroupKind?) -> String {
        switch kind {
        case .family: return Copy.groupsCreateTypeFamilyDetail
        case .roommates: return Copy.groupsCreateTypeRoommatesDetail
        case .custom, .unknown: return Copy.groupsCreateTypeCustomDetail
        case .friends, .none: return Copy.groupsCreateTypeFriendsDetail
        }
    }

    /// `groups.screen.created.invite.*`
    static func createdInvite(_ kind: GroupKind?) -> String {
        switch kind {
        case .family: return Copy.groupsScreenCreatedInviteFamily
        case .roommates: return Copy.groupsScreenCreatedInviteRoommates
        case .custom, .unknown: return Copy.groupsScreenCreatedInviteCustom
        case .friends, .none: return Copy.groupsScreenCreatedInviteFriends
        }
    }

    /// `groups.settings.members.invite.*`
    static func settingsInvite(_ kind: GroupKind?) -> String {
        switch kind {
        case .family: return Copy.groupsSettingsMembersInviteFamily
        case .roommates: return Copy.groupsSettingsMembersInviteRoommates
        case .custom, .unknown: return Copy.groupsSettingsMembersInviteCustom
        case .friends, .none: return Copy.groupsSettingsMembersInviteFriends
        }
    }
}
