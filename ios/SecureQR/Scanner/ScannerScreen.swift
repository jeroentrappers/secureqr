import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

/// Screen 1: full-bleed camera, reticle, hint and the three round buttons.
/// Always dark, whatever the system appearance.
struct ScannerScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var camera = CameraController()
    @State private var authorization = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var photoItem: PhotosPickerItem?
    @State private var isReadingPhoto = false
    @State private var showNoCodeAlert = false

    private var isAuthorized: Bool {
        return authorization == .authorized
    }

    private var showsLiveCamera: Bool {
        return isAuthorized && !camera.isUnavailable
    }

    var body: some View {
        ZStack {
            Theme.Scanner.background.ignoresSafeArea()

            if showsLiveCamera {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                ReticleView()
            }

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                centerMessage
                Spacer(minLength: 0)
                if showsLiveCamera {
                    hint
                }
                tools
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            camera.onDetect = { text in
                handleDetected(text)
            }
            refreshAuthorization()
            updateCamera()
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: model.isScannerFrontmost) { _ in updateCamera() }
        // Pinch anywhere on the scan screen to zoom the camera.
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { scale in
                    if showsLiveCamera { camera.pinch(scale: scale) }
                }
                .onEnded { _ in camera.endPinch() }
        )
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                // The user may have changed the permission in Settings.
                refreshAuthorization()
            }
            updateCamera()
        }
        .onChange(of: authorization) { _ in updateCamera() }
        .onChange(of: photoItem) { item in
            guard let item = item else { return }
            readPhoto(item)
        }
        .alert(L("scan.photo.none.title"), isPresented: $showNoCodeAlert) {
            Button(L("common.ok"), role: .cancel) {}
        } message: {
            Text(L("scan.photo.none.message"))
        }
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack {
            BrandBar(ink: Theme.Scanner.text, accent: Theme.Scanner.text, markSize: 28, fontSize: 20)
            Spacer()
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 10)
    }

    @ViewBuilder
    private var centerMessage: some View {
        switch authorization {
        case .authorized:
            if camera.isUnavailable {
                ScannerMessage(
                    symbolName: "video.slash",
                    title: L("scan.unavailable.title"),
                    message: L("scan.unavailable.message"),
                    buttonTitle: nil,
                    action: {}
                )
            }
        case .notDetermined:
            ScannerMessage(
                symbolName: "camera",
                title: L("scan.permission.title"),
                message: L("scan.permission.message"),
                buttonTitle: L("scan.permission.continue"),
                action: requestCameraAccess
            )
        default:
            ScannerMessage(
                symbolName: "video.slash",
                title: L("scan.denied.title"),
                message: L("scan.denied.message"),
                buttonTitle: L("scan.denied.settings"),
                action: openSettings
            )
        }
    }

    private var hint: some View {
        (Text(L("scan.hint.before"))
            + Text(L("scan.hint.strong")).foregroundColor(Theme.Scanner.accent).fontWeight(.heavy)
            + Text(L("scan.hint.after")))
            .font(AppFont.ui(15, .regular, relativeTo: .subheadline))
            .foregroundColor(Theme.Scanner.text)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Theme.Scanner.pill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 16)
    }

    private var tools: some View {
        HStack {
            Spacer()
            Button(action: { camera.toggleTorch() }) {
                ToolIcon(symbolName: camera.isTorchOn ? "bolt.fill" : "bolt.slash.fill", isActive: camera.isTorchOn)
            }
            .disabled(!showsLiveCamera || !camera.hasTorch)
            .opacity(showsLiveCamera && camera.hasTorch ? 1 : 0.4)
            .accessibilityLabel(Text(L(camera.isTorchOn ? "scan.torch.off" : "scan.torch.on")))
            Spacer()
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                ZStack {
                    ToolIcon(symbolName: "photo.on.rectangle", isActive: false)
                        .opacity(isReadingPhoto ? 0.4 : 1)
                    if isReadingPhoto {
                        ProgressView().tint(.white)
                    }
                }
            }
            .disabled(isReadingPhoto)
            .accessibilityLabel(Text(L("scan.photo")))
            Spacer()
            Button(action: { model.showHistory() }) {
                ToolIcon(symbolName: "clock.arrow.circlepath", isActive: false)
            }
            .accessibilityLabel(Text(L("scan.history")))
            Spacer()
        }
        .padding(.bottom, 18)
    }

    // MARK: - Behaviour

    private func updateCamera() {
        if isAuthorized && model.isScannerFrontmost && scenePhase == .active {
            camera.start()
        } else {
            camera.stop()
        }
    }

    private func refreshAuthorization() {
        authorization = AVCaptureDevice.authorizationStatus(for: .video)
    }

    private func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { _ in
            DispatchQueue.main.async {
                refreshAuthorization()
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func handleDetected(_ text: String) {
        guard model.isScannerFrontmost else { return }
        if model.handleScan(text) {
            Haptics.success()
        } else {
            // Nothing usable in the code: keep looking.
            updateCamera()
        }
    }

    private func readPhoto(_ item: PhotosPickerItem) {
        isReadingPhoto = true
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            var text: String?
            if let data = data {
                text = await ImageQRDetector.detect(in: data)
            }
            photoItem = nil
            isReadingPhoto = false
            if let text = text, model.isScannerFrontmost, model.handleScan(text) {
                Haptics.success()
            } else {
                showNoCodeAlert = true
            }
        }
    }
}

/// Round translucent button used in the bottom row.
private struct ToolIcon: View {
    let symbolName: String
    let isActive: Bool

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 21, weight: .semibold))
            .foregroundColor(isActive ? Theme.Scanner.onAccent : Theme.Scanner.text)
            .frame(width: 58, height: 58)
            .background(Circle().fill(isActive ? Theme.Scanner.accent : Theme.Scanner.control))
    }
}

/// Explanation shown in place of the camera picture.
private struct ScannerMessage: View {
    let symbolName: String
    let title: String
    let message: String
    let buttonTitle: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(Theme.Scanner.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(AppFont.ui(22, .heavy, relativeTo: .title2))
                .foregroundColor(Theme.Scanner.text)
                .multilineTextAlignment(.center)
            Text(message)
                .font(AppFont.ui(16, .regular, relativeTo: .body))
                .foregroundColor(Theme.Scanner.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let buttonTitle = buttonTitle {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(AppFont.ui(17, .bold, relativeTo: .headline))
                        .foregroundColor(Theme.Scanner.onAccent)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Theme.Scanner.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                }
                .padding(.top, 6)
            }
        }
        .padding(.horizontal, 32)
    }
}

/// Four corner brackets.
struct ReticleShape: Shape {
    var armLength: CGFloat
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let arm = armLength
        let radius = cornerRadius
        var path = Path()

        // top left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))

        // top right
        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))

        // bottom right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))

        // bottom left
        path.move(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - arm))

        return path
    }
}

struct ReticleView: View {
    var size: CGFloat = 250

    var body: some View {
        ReticleShape(armLength: 46, cornerRadius: Theme.radius + 2)
            .stroke(Theme.Scanner.accent, style: StrokeStyle(lineWidth: 5, lineCap: .butt, lineJoin: .round))
            .frame(width: size, height: size)
            .offset(y: -40)
            .accessibilityHidden(true)
    }
}
