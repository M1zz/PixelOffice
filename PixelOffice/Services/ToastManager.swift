import Foundation
import SwiftUI
import UserNotifications

/// 토스트 메시지 타입
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let type: ToastType
    let duration: TimeInterval

    init(title: String, message: String, type: ToastType = .info, duration: TimeInterval = 3.0) {
        self.title = title
        self.message = message
        self.type = type
        self.duration = duration
    }
}

enum ToastType {
    case info
    case success
    case warning
    case error

    var color: Color {
        switch self {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
}

/// 앱 전체 토스트 관리자
@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var currentToast: ToastMessage?
    @Published var toastQueue: [ToastMessage] = []

    private var dismissTask: Task<Void, Never>?

    private init() {
        requestNotificationPermission()
    }

    /// 알림 권한 요청
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("알림 권한 요청 실패: \(error)")
            }
        }
    }

    /// 토스트 표시
    func show(_ toast: ToastMessage) {
        dismissTask?.cancel()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentToast = toast
        }

        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        currentToast = nil
                    }
                }
            }
        }
    }

    /// 간편 토스트 표시
    func show(title: String, message: String, type: ToastType = .info) {
        show(ToastMessage(title: title, message: message, type: type))
    }

    /// 시스템 알림 보내기
    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // 즉시 발송
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("알림 발송 실패: \(error)")
            }
        }
    }

    /// 토스트 숨기기
    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            currentToast = nil
        }
    }
}

/// 토스트 뷰
struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .font(.title2)
                .foregroundStyle(toast.type.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.headline)
                Text(toast.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                ToastManager.shared.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .padding(.horizontal)
    }
}

/// 토스트 오버레이 모디파이어
struct ToastOverlay: ViewModifier {
    @ObservedObject var toastManager = ToastManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toastManager.currentToast {
                    ToastView(toast: toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
    }
}

extension View {
    func withToastOverlay() -> some View {
        modifier(ToastOverlay())
    }
}
