// Surface: groups.invite — the in-app QR invite card (owner decision 17; design/surfaces/groups.invite.md "QR card";
// token groups.invite.layout.qrCard). References: references/auto/retro/press/tc-2024-04-retro-journals-5.png (TC-J5
// phone 2: "QR Code" first of the share targets), references/auto/retro/apk/retro-android-2026.10.1150-strings.txt
// (APK-S: qr_card_content_subtitle, journal_qr_code_action_sheet_title), references/auto/retro/press/tc-2023-12-recaps.png
// (TC-REC: the recap card the code sits in) and references/auto/retro/store/retro-store-04.png (ST-04: the recap preview
// around it). Encoding as the web invite page (web/src/render/qr.ts): error correction H, whole-pixel modules, black on
// white, a four-module quiet zone. Composition of C-34, C-11 and C-09 in the recap preview (`RecapPreviewScreen`).
import AppServices
import CoreImage
import CoreImage.CIFilterBuiltins
import DesignSystem
import Observation
import SwiftUI
import UIKit

// MARK: - Encoding

/// The modules of a QR symbol without its quiet zone: `size` × `size`, row-major, true = dark.
struct QRMatrix: Equatable, Sendable {
    let size: Int
    let modules: [Bool]

    func isDark(x: Int, y: Int) -> Bool { modules[y * size + x] }
}

/// QR encoding of an invite link (`groups.invite.layout.qrCard`): CoreImage's `CIQRCodeGenerator` at error correction H,
/// the URL's UTF-8 bytes (ASCII for an https link: byte mode, as the web page encodes it).
enum InviteQRCode {
    private typealias Spec = Tokens.Layouts.GroupsInviteLayoutQrCard

    /// Modules of white around the symbol on each side (`quietZoneModules`; DENSO WAVE: four).
    static var quietZone: Int { Int(Spec.quietZoneModules) }

    /// The symbol of `link`, read back from the generator's one-pixel-per-module image (its own margin trimmed to the
    /// dark modules' bounds — the three finder patterns reach three corners); nil if the generator fails.
    static func matrix(for link: String) -> QRMatrix? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(link.utf8)
        filter.correctionLevel = Spec.errorCorrection
        guard let output = filter.outputImage else { return nil }
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let image = context.createCGImage(output, from: output.extent.integral) else { return nil }
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 255, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let gray = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            gray.interpolationQuality = .none
            gray.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        let threshold: UInt8 = 128 // provenance-ok: midpoint between the generator's black (0) and white (255)
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[y * width + x] < threshold {
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        let size = maxX - minX + 1
        guard maxX >= 0, size == maxY - minY + 1 else { return nil }
        var modules = [Bool](repeating: false, count: size * size)
        for y in 0..<size {
            for x in 0..<size {
                modules[y * size + x] = pixels[(y + minY) * width + x + minX] < threshold
            }
        }
        return QRMatrix(size: size, modules: modules)
    }

    /// The symbol with its quiet zone, one pixel per module: the dark modules opaque, everything else clear (the caller
    /// tints the modules `moduleColor` and puts them on the card's white).
    static func image(of matrix: QRMatrix) -> CGImage? {
        let side = matrix.size + 2 * quietZone
        let channels = 4 // provenance-ok: RGBA bytes per pixel
        // RGBA, premultiplied: opaque for a dark module (the tint colours it), fully clear elsewhere.
        var pixels = [UInt8](repeating: 0, count: side * side * channels)
        for y in 0..<matrix.size {
            for x in 0..<matrix.size where matrix.isDark(x: x, y: y) {
                pixels[((y + quietZone) * side + x + quietZone) * channels + channels - 1] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8 * channels, bytesPerRow: side * channels,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    /// Side of one module in whole pixels for a square `pixels` wide holding the symbol and its quiet zone (web:
    /// `floor(size / modules)`), never below one pixel.
    static func modulePixels(side pixels: CGFloat, symbolSize: Int) -> CGFloat {
        max(1, (pixels / CGFloat(symbolSize + 2 * quietZone)).rounded(.down))
    }
}

/// The symbol in `color.global.onSurfaceLight` square modules of a whole number of pixels, nearest-neighbour, centred
/// in a `side` × `side` square; the white around it (the card) is the quiet zone. Decorative: the card carries the label.
struct QRCodeView: View {
    let matrix: QRMatrix
    let side: CGFloat
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let modules = matrix.size + 2 * InviteQRCode.quietZone
        let modulePixels = InviteQRCode.modulePixels(side: side * displayScale, symbolSize: matrix.size)
        let drawnPixels = modulePixels * CGFloat(modules)
        let inset = ((side * displayScale - drawnPixels) / 2).rounded(.down) / displayScale
        ZStack(alignment: .topLeading) {
            Color.clear
            if let image = InviteQRCode.image(of: matrix) {
                Image(decorative: image, scale: 1)
                    .renderingMode(.template)
                    .interpolation(.none)
                    .resizable()
                    .foregroundStyle(Tokens.Colors.globalOnSurfaceLight)
                    .frame(width: drawnPixels / displayScale, height: drawnPixels / displayScale)
                    .offset(x: inset, y: inset)
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

// MARK: - Card

/// The QR card (`groups.invite.layout.qrCard`): Retro's recap card shell (`layout.year.story.recapCard`, white in both
/// appearances — L-4) `width` wide, corners `cornerRadiusRatio` × the width (continuous), padding `paddingRatio` × the
/// width; the symbol of `link` in its square grid area (width − 2 × padding); then the footer, `footerHeightRatio` × the
/// width, its two lines centred in it at the padding: the group's name (text role `displayTitle`,
/// `color.global.onSurfaceLight`, one line) over `groups.invite.qr.tagline` (`groups.invite.fontSize.qrTagline` in
/// `font.global.family`, `groups.invite.color.note`). A picture (also the saved / shared image): its text keeps the
/// default size. VoiceOver: one image, `groups.invite.qr.accessibilityLabel`.
struct InviteQRCard: View {
    let groupName: String
    let width: CGFloat
    let matrix: QRMatrix?

    private typealias Card = Tokens.Layouts.YearStoryRecapCard

    init(link: String, groupName: String, width: CGFloat) {
        self.init(matrix: InviteQRCode.matrix(for: link), groupName: groupName, width: width)
    }

    init(matrix: QRMatrix?, groupName: String, width: CGFloat) {
        self.matrix = matrix
        self.groupName = groupName
        self.width = width
    }

    var body: some View {
        let padding = width * Card.paddingRatio
        let side = max(0, width - 2 * padding)
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let matrix {
                    QRCodeView(matrix: matrix, side: side)
                } else {
                    Color.clear.frame(width: side, height: side)
                }
            }
            .padding([.top, .horizontal], padding)
            VStack(alignment: .leading, spacing: 0) {
                Text(groupName)
                    .dsTextStyle(TextRole.displayTitle)
                    .foregroundStyle(Tokens.Colors.globalOnSurfaceLight)
                    .lineLimit(1)
                Text(Copy.groupsInviteQrTagline)
                    .font(Tokens.Fonts.globalFamily.font(size: Tokens.FontSizes.groupsInviteFontSizeQrTagline, weight: Font.Weight.regular))
                    .foregroundStyle(Tokens.Colors.groupsInviteColorNote)
                    .lineLimit(1)
            }
            .padding(.horizontal, padding)
            .frame(width: width, height: width * Card.footerHeightRatio, alignment: .leading)
        }
        .frame(width: width)
        .background(Tokens.Colors.globalSurfaceLight, in: DSShape.rounded(width * Card.cornerRadiusRatio))
        .environment(\.dynamicTypeSize, .large)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Copy.groupsInviteQrAccessibilityLabel(groupName: groupName)))
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("groups.invite.qr.card")
    }

    /// The card alone as a PNG at `exportScale` (Save / Share; `groups.invite.layout.qrCard` export).
    @MainActor
    func renderedImage() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = Tokens.Layouts.GroupsInviteLayoutQrCard.exportScale
        return renderer.uiImage
    }
}

// MARK: - Screen

/// State of the QR screen: the encoded link and Save's outcome (`groups.invite.qr.saved` / `.saveFailed`, the denied
/// alert), with the haptic triggers (`haptic.global.success` / `haptic.global.error`).
@MainActor
@Observable
final class GroupInviteQRModel: Identifiable {
    let link: URL
    let groupName: String
    let cover: PhotoSource?
    let matrix: QRMatrix?
    private(set) var isSaving = false
    /// The native alert `groups.invite.qr.saveDenied.*` (photo access denied).
    var showsSaveDenied = false
    private(set) var successCount = 0
    private(set) var errorCount = 0

    private let toasts: ToastCenter
    private let saveImage: @Sendable (Data) async throws -> Void

    /// - Parameter saveImage: saves PNG data with add-only photo access (`PhotoLibraryService.saveImage`).
    init(
        link: URL,
        groupName: String,
        cover: PhotoSource?,
        toasts: ToastCenter,
        saveImage: @escaping @Sendable (Data) async throws -> Void = { try await PhotoLibraryService().saveImage($0) }
    ) {
        self.link = link
        self.groupName = groupName
        self.cover = cover
        self.matrix = InviteQRCode.matrix(for: link.absoluteString)
        self.toasts = toasts
        self.saveImage = saveImage
    }

    /// "Save": the card image into the photo library.
    func save(png: Data?) async {
        guard !isSaving else { return }
        guard let png else {
            errorCount += 1
            toasts.show(Copy.groupsInviteQrSaveFailed)
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await saveImage(png)
            successCount += 1
            toasts.show(Copy.groupsInviteQrSaved)
        } catch {
            errorCount += 1
            if case .notAuthorized? = error as? PhotoLibraryService.LibraryError {
                showsSaveDenied = true
            } else {
                toasts.show(Copy.groupsInviteQrSaveFailed)
            }
        }
    }
}

/// The QR screen (`groups.invite.layout.qrCard` presentation): Retro's recap preview — the group's cover blurred in the
/// media page (`BlurredBackdrop`; no cover → `color.global.controlOnDeep`), the `InviteQRCard` centred at the recap
/// card's width ratio of the page, the close circle, the Save circle (C-11 on media, `icon.global.download`) leading and
/// the light "Share" pill (C-09) trailing. Save and Share use the card alone. A media surface: dark in both appearances.
/// Focus order: card → Save → Share → close.
struct GroupInviteQRScreen: View {
    @State private var model: GroupInviteQRModel
    @State private var share: ShareRequest?
    @State private var cardWidth: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    init(model: GroupInviteQRModel) {
        _model = State(initialValue: model)
    }

    private var card: InviteQRCard {
        InviteQRCard(matrix: model.matrix, groupName: model.groupName, width: cardWidth)
    }

    var body: some View {
        RecapPreviewScreen { geometry in
            let width = geometry.frame.width * Tokens.Layouts.YearStoryRecapCard.widthRatio
            ZStack {
                if let cover = model.cover {
                    BlurredBackdrop(source: cover)
                } else {
                    Tokens.Colors.globalControlOnDeep
                }
                InviteQRCard(matrix: model.matrix, groupName: model.groupName, width: width)
                    .task(id: width) { cardWidth = width }
                    .accessibilitySortPriority(4)
            }
        } overlay: { geometry in
            RecapPreviewClose(geometry: geometry, accessibilityLabel: Copy.groupsInviteCloseAccessibilityLabel) { dismiss() }
                .accessibilityIdentifier("groups.invite.qr.close")
                .accessibilitySortPriority(1)
        } leading: {
            CircleButton(icon: Tokens.Icons.globalDownload, accessibilityLabel: Copy.groupsInviteQrSave, style: .media) {
                guard cardWidth > 0 else { return }
                Task { await model.save(png: card.renderedImage()?.pngData()) }
            }
            .disabled(model.isSaving)
            .accessibilityIdentifier("groups.invite.qr.save")
            .accessibilitySortPriority(3)
        } trailing: {
            RecapPill(Copy.groupsInviteQrShare) {
                guard cardWidth > 0, let image = card.renderedImage() else { return }
                share = ShareRequest(items: [image])
            }
            .accessibilityIdentifier("groups.invite.qr.share")
            .accessibilitySortPriority(2)
        }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .sheet(item: $share) { request in
            ActivityView(items: request.items)
                .presentationDetents([.medium, .large])
        }
        .alert(Copy.groupsInviteQrSaveDeniedTitle, isPresented: $model.showsSaveDenied) {
            Button(Copy.groupsInviteQrSaveDeniedButton) {
                if let settings = URL(string: UIApplication.openSettingsURLString) { openURL(settings) }
            }
            Button(Copy.groupsInviteQrSaveDeniedCancel, role: .cancel) {}
        } message: {
            Text(Copy.groupsInviteQrSaveDeniedMessage)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(Copy.groupsInviteQrTitle))
        .accessibilityIdentifier("groups.invite.qr.screen")
    }
}
