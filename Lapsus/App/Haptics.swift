import UIKit

/// Vibraciones cortas. Respetan el ajuste "Vibración".
@MainActor
enum Haptics {
    static var enabled = true

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let softGen = UIImpactFeedbackGenerator(style: .soft)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    /// Toque sobre la ilustración para iniciar o reanudar.
    static func orb() {
        guard enabled else { return }
        medium.impactOccurred(intensity: 0.8)
        medium.prepare()
    }

    /// Pausa: un golpe más blando que el de iniciar.
    static func pause() {
        guard enabled else { return }
        softGen.impactOccurred(intensity: 0.9)
        softGen.prepare()
    }

    /// Toque suave (chips, interruptores).
    static func tap() {
        guard enabled else { return }
        light.impactOccurred()
        light.prepare()
    }

    static func tick() {
        guard enabled else { return }
        selection.selectionChanged()
        selection.prepare()
    }

    /// Guardar (reanudar tras el modal, cerrar el día).
    static func success() {
        guard enabled else { return }
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    static func warmUp() {
        guard enabled else { return }
        medium.prepare()
        softGen.prepare()
    }
}
