//
//  InputSourceMonitor.swift
//  Zili
//

import Foundation

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import Carbon
#endif

/// Watches whether the learner can type Chinese right now, so the listening quiz — where they hear
/// a sentence and type it back — can warn them before they're stuck at a keyboard that can't
/// produce Hanzi. It reads the platform's active input source and updates live as the learner
/// switches keyboards. Detection is best-effort: when the platform gives no answer the monitor
/// stays ``Availability/unknown`` and the quiz shows no warning, so a false alarm never nags.
@MainActor
@Observable
final class InputSourceMonitor {
  private(set) var availability: Availability

  /// Tokens for the input-source observers, held so `deinit` can hand them to the thread-safe
  /// `removeObserver`. Plumbing, not observable state.
  @ObservationIgnored nonisolated(unsafe) private var observers: [any NSObjectProtocol] = []

  /// Whether the quiz should show its "no Chinese keyboard" warning — only when we positively
  /// determined none is available.
  var shouldWarnNoChineseInput: Bool {
    availability == .unavailable
  }

  init() {
    availability = Self.currentAvailability()
    observeChanges()
  }

  /// Reads the platform's current Chinese-input availability. On iOS this is the language of the
  /// keyboard the focused field is actually using — so switching keyboards mid-quiz is reflected —
  /// falling back to ``Availability/unknown`` before any field is focused. On macOS it's a language
  /// of the current input source.
  private static func currentAvailability() -> Availability {
    #if os(iOS)
      guard let language = FirstResponder.textInputMode?.primaryLanguage else { return .unknown }
      return language.hasPrefix("zh") ? .available : .unavailable
    #elseif os(macOS)
      guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
        let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages)
      else { return .unknown }
      let languages =
        Unmanaged<CFArray>.fromOpaque(pointer).takeUnretainedValue() as? [String] ?? []
      return languages.contains { $0.hasPrefix("zh") } ? .available : .unavailable
    #else
      return .unknown
    #endif
  }

  private func refresh() {
    availability = Self.currentAvailability()
  }

  /// Subscribes to the platform's input-source-change notification so the warning clears the moment
  /// the learner switches to a Chinese keyboard. On iOS the keyboard-appearance notification is also
  /// observed, since that is when a field first gains an input mode to read.
  private func observeChanges() {
    #if os(iOS)
      observe(UITextInputMode.currentInputModeDidChangeNotification, on: .default)
      observe(UIResponder.keyboardDidShowNotification, on: .default)
    #elseif os(macOS)
      let name = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
      observe(name, on: DistributedNotificationCenter.default())
    #endif
  }

  /// Registers a refresh for `name`, deferring the read to the next runloop turn so the platform's
  /// input state has settled before we sample it.
  private func observe(_ name: Notification.Name, on center: NotificationCenter) {
    let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
      DispatchQueue.main.async {
        MainActor.assumeIsolated { self?.refresh() }
      }
    }
    observers.append(token)
  }

  #if os(macOS)
    private func observe(_ name: Notification.Name, on center: DistributedNotificationCenter) {
      let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.refresh() }
      }
      observers.append(token)
    }
  #endif

  deinit {
    #if os(macOS)
      let distributed = DistributedNotificationCenter.default()
    #endif
    for observer in observers {
      #if os(macOS)
        distributed.removeObserver(observer)
      #else
        NotificationCenter.default.removeObserver(observer)
      #endif
    }
  }

  /// Whether a Chinese input source is available to the learner.
  enum Availability {
    case available
    case unavailable
    case unknown
  }
}

#if os(iOS)
  /// Reaches the app's current first responder to read the keyboard it is using. `UIKit` exposes the
  /// active keyboard only through the responder chain, so a `nil`-targeted action is sent to capture
  /// whichever object is first responder, and its ``UIResponder/textInputMode`` is the live keyboard.
  @MainActor
  private enum FirstResponder {
    private static weak var captured: UIResponder?

    static var textInputMode: UITextInputMode? {
      captured = nil
      UIApplication.shared.sendAction(
        #selector(UIResponder.captureAsFirstResponder),
        to: nil,
        from: nil,
        for: nil
      )
      defer { captured = nil }
      return captured?.textInputMode
    }

    static func capture(_ responder: UIResponder) {
      captured = responder
    }
  }

  @MainActor
  private extension UIResponder {
    @objc
    func captureAsFirstResponder() {
      FirstResponder.capture(self)
    }
  }
#endif
