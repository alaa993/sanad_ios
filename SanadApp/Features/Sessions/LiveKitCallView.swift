import SwiftUI
import LiveKit
import AVFoundation
import Combine

/// Owns a LiveKit `Room`: connect with server JWT, publish mic/camera, track remote A/V for the call UI.
@MainActor
final class LiveKitCallViewModel: ObservableObject {
    @Published var status = NSLocalizedString("call_status_connecting", comment: "")
    @Published var error: String?
    @Published var micEnabled = true
    @Published var cameraEnabled = true
    @Published var localVideoTrack: LocalVideoTrack?
    @Published var remoteVideoTracks: [String: VideoTrack] = [:]
    @Published var remoteAudioOnlyCount = 0

    let room = Room()
    private var cancellables = Set<AnyCancellable>()

    func connect(url: String, token: String, enableVideo: Bool) async {
        do {
            try await configureAudioSession()
            try await room.connect(url: url, token: token)
            room.add(delegate: self)
            try await room.localParticipant.setMicrophone(enabled: true)
            if enableVideo {
                try await room.localParticipant.setCamera(enabled: true)
            }
            cameraEnabled = enableVideo
            refreshTracks()
            status = NSLocalizedString("call_status_connected", comment: "")
        } catch {
            status = NSLocalizedString("call_status_failed", comment: "")
            self.error = NSLocalizedString("call_error_failed", comment: "")
        }
    }

    func reconnect(url: String, token: String, enableVideo: Bool) async {
        await disconnect()
        status = NSLocalizedString("call_status_connecting", comment: "")
        error = nil
        await connect(url: url, token: token, enableVideo: enableVideo)
    }

    func toggleMic() async {
        micEnabled.toggle()
        try? await room.localParticipant.setMicrophone(enabled: micEnabled)
    }

    func toggleCamera() async {
        cameraEnabled.toggle()
        try? await room.localParticipant.setCamera(enabled: cameraEnabled)
        refreshTracks()
    }

    func disconnect() async {
        room.remove(delegate: self)
        await room.disconnect()
        localVideoTrack = nil
        remoteVideoTracks = [:]
        remoteAudioOnlyCount = 0
        status = NSLocalizedString("call_status_ended", comment: "")
    }

    func refreshTracks() {
        localVideoTrack = room.localParticipant.firstCameraVideoTrack as? LocalVideoTrack
        var remotes: [String: VideoTrack] = [:]
        var audioOnly = 0
        for participant in room.remoteParticipants.values {
            if let video = participant.firstCameraVideoTrack {
                remotes[participant.identity?.stringValue ?? participant.sid?.stringValue ?? "remote"] = video
            } else if participant.firstAudioTrack != nil {
                audioOnly += 1
            }
        }
        remoteVideoTracks = remotes
        remoteAudioOnlyCount = audioOnly
    }

    private func configureAudioSession() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
        try session.setActive(true)
    }
}

extension LiveKitCallViewModel: RoomDelegate {
    nonisolated func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            self.refreshTracks()
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            self.refreshTracks()
        }
    }

    nonisolated func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        Task { @MainActor in
            self.refreshTracks()
        }
    }

    nonisolated func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        Task { @MainActor in
            self.refreshTracks()
        }
    }

    nonisolated func room(_ room: Room, participant: LocalParticipant, didPublishTrack publication: LocalTrackPublication) {
        Task { @MainActor in
            self.refreshTracks()
        }
    }
}

/// SwiftUI shell for an in-session LiveKit call (video when callMode contains "video").
struct LiveKitCallView: View {
    let sessionId: Int
    let callMode: String
    let liveKit: LiveKitTokenResponse

    @StateObject private var vm = LiveKitCallViewModel()
    @Environment(\.dismiss) private var dismiss

    private var enableVideo: Bool { callMode.lowercased().contains("video") }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SanadTheme.primaryDark.opacity(0.95),
                    SanadTheme.primary.opacity(0.85),
                    SanadTheme.surfaceAlt
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                SanadHeroHeader(title: "call_title_in_app", subtitle: "call_mode_label")

                VStack(spacing: 16) {
                    Text(String(format: NSLocalizedString("call_mode_label", comment: ""), callModeLabel()))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)

                    videoStage

                    SanadListCard {
                        VStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(SanadTheme.primary.opacity(0.2))
                                    .frame(width: 8, height: 8)
                                Text(vm.status)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(SanadTheme.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if let err = vm.error {
                                Text(err)
                                    .font(.system(size: 12))
                                    .foregroundColor(SanadTheme.error)
                                Button("cta_retry") {
                                    guard let url = liveKit.url, let token = liveKit.token else { return }
                                    Task { await vm.reconnect(url: url, token: token, enableVideo: enableVideo) }
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(SanadTheme.primary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                Spacer()

                callControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
            }
        }
        .onAppear {
            guard let url = liveKit.url, let token = liveKit.token, !url.isEmpty, !token.isEmpty else {
                vm.error = NSLocalizedString("call_error_missing", comment: "")
                vm.status = NSLocalizedString("call_status_unavailable", comment: "")
                return
            }
            Task { await vm.connect(url: url, token: token, enableVideo: enableVideo) }
        }
        .onDisappear { Task { await vm.disconnect() } }
    }

    private var videoStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(SanadTheme.primary.opacity(0.12))

            if let remote = vm.remoteVideoTracks.values.first {
                SwiftUIVideoView(remote, layoutMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else if !enableVideo || vm.remoteAudioOnlyCount > 0 {
                VStack(spacing: 12) {
                    SanadIcon.mic.image
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(SanadTheme.primary.opacity(0.7))
                    Text(enableVideo ? "call_mode_video" : "call_mode_voice")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(SanadTheme.placeholder)
                }
            } else {
                VStack(spacing: 12) {
                    SanadIcon.cam.image
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(SanadTheme.primary.opacity(0.7))
                    Text("call_mode_video")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(SanadTheme.placeholder)
                }
            }

            if enableVideo, let local = vm.localVideoTrack {
                SwiftUIVideoView(local, layoutMode: .fill)
                    .frame(width: 110, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(SanadTheme.onPrimary.opacity(0.4), lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(14)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .shadow(color: SanadTheme.subtleShadow, radius: 12, y: 6)
    }

    private var callControls: some View {
        HStack(spacing: 20) {
            controlButton(icon: vm.micEnabled ? "mic.fill" : "mic.slash.fill", label: "call_mic") {
                Task { await vm.toggleMic() }
            }
            if enableVideo {
                controlButton(icon: vm.cameraEnabled ? "video.fill" : "video.slash.fill", label: "call_camera") {
                    Task { await vm.toggleCamera() }
                }
            }
            controlButton(icon: "phone.down.fill", label: "call_end", tint: .red, filled: true) {
                Task {
                    await vm.disconnect()
                    dismiss()
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            Capsule()
                .fill(SanadTheme.surface.opacity(0.95))
                .shadow(color: SanadTheme.subtleShadow, radius: 16, y: 4)
        )
    }

    private func controlButton(
        icon: String,
        label: LocalizedStringKey,
        tint: Color = SanadTheme.primary,
        filled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                SanadIcon.forShortcut(id: icon).view(size: 22)
                    .foregroundColor(filled ? SanadTheme.onPrimary : tint)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(filled ? tint : SanadTheme.primary.opacity(0.1))
                    )
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(SanadTheme.placeholder)
            }
        }
    }

    private func callModeLabel() -> String {
        if callMode.lowercased().contains("video") { return NSLocalizedString("call_mode_video", comment: "") }
        if callMode.lowercased().contains("voice") { return NSLocalizedString("call_mode_voice", comment: "") }
        return NSLocalizedString("call_mode_default", comment: "")
    }
}

#Preview {
    LiveKitCallView(sessionId: 1, callMode: "video",
                    liveKit: LiveKitTokenResponse(token: "t", url: "wss://example", room: "room"))
}
