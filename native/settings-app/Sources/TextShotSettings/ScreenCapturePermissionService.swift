import CoreGraphics
import Foundation

protocol ScreenCapturePermissionChecking {
    func preflightAuthorized() -> Bool
    func requestIfNeededOncePerLaunch() -> Bool
    func ensureAuthorized() async -> Bool
}

protocol ScreenCaptureAuthorizationAPI: Sendable {
    func preflight() -> Bool
    func request() -> Bool
}

struct SystemScreenCaptureAuthorizationAPI: ScreenCaptureAuthorizationAPI {
    func preflight() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func request() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}

final class ScreenCapturePermissionService: ScreenCapturePermissionChecking {
    private let authorizationAPI: ScreenCaptureAuthorizationAPI
    private let stateQueue = DispatchQueue(label: "com.textshot.screen-capture-permission")
    private var didRequestThisLaunch = false

    init(authorizationAPI: ScreenCaptureAuthorizationAPI = SystemScreenCaptureAuthorizationAPI()) {
        self.authorizationAPI = authorizationAPI
    }

    func preflightAuthorized() -> Bool {
        authorizationAPI.preflight()
    }

    func requestIfNeededOncePerLaunch() -> Bool {
        if authorizationAPI.preflight() {
            return true
        }

        let shouldRequest = stateQueue.sync { () -> Bool in
            guard !didRequestThisLaunch else {
                return false
            }

            didRequestThisLaunch = true
            return true
        }

        guard shouldRequest else {
            return false
        }

        return authorizationAPI.request()
    }

    func ensureAuthorized() async -> Bool {
        if preflightAuthorized() {
            return true
        }

        let requestedThisAttempt = stateQueue.sync { () -> Bool in
            guard !didRequestThisLaunch else {
                return false
            }

            didRequestThisLaunch = true
            return true
        }

        guard requestedThisAttempt else {
            return false
        }

        if await requestAccessOffMainThread() {
            return true
        }

        return await waitForAuthorizationPropagation()
    }

    private func requestAccessOffMainThread() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [authorizationAPI] in
                continuation.resume(returning: authorizationAPI.request())
            }
        }
    }

    private func waitForAuthorizationPropagation() async -> Bool {
        for _ in 0..<40 {
            if authorizationAPI.preflight() {
                return true
            }

            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        return authorizationAPI.preflight()
    }
}
