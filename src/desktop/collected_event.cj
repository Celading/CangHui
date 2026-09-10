package chui.desktop

import sdl.UiEvent

/** Coordinates were normalized by SDL before the owner drained its work queue. */
internal struct DesktopCollectedEvent {
    let event: UiEvent
    let transformRevision: UInt64
    let modifierMask: ?UInt16

    init(event: UiEvent, transformRevision: UInt64, modifierMask!: ?UInt16 = None) {
        this.event = event
        this.transformRevision = transformRevision
        this.modifierMask = modifierMask
    }

    func validAt(revision: UInt64): Bool {
        if (transformRevision == revision) { return true }
        match (event) {
            case UiEvent.MouseMove(_, _) => false
            case UiEvent.MouseDown(_, _, _) => false
            case UiEvent.MouseUp(_, _, _) => false
            case UiEvent.MouseWheel(_, _, _, _) => false
            case UiEvent.Pointer(_) => false
            case _ => true
        }
    }
}
