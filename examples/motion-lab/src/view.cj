package canghui_motion_lab

import chui.*
import canghui_kit.*

public func motionLabView(state: MotionLabState): Unit {
    let family = MOTION_FAMILIES[state.family.value]
    let palette = kitMotionPalette(family, dark: state.dark.value)
    ScrollView {
        VStack(spacing: 24.vp) {
            Row(space: 12.vp) {
                Label("CANGHUI  /  MOTION STUDIO", fontSize: 12.fp).bold().layoutWeight(1.0)
                Label("FIVE STUDIES", fontSize: 10.fp).muted()
            }.hug()
            FlowRow {
                for (i in 0..MOTION_FAMILIES.size) {
                    Button("0${i + 1}  " + MOTION_FAMILIES[i].name(), probedAction("family-${i}", {=>
                        state.family.value = i
                    })).key("family-${i}").buttonStyle(ButtonStyle.quiet())
                }
            }.spacing(6.vp).probe("families", "MotionFamilyPicker")
            if (state.width.value >= 760.0) {
                HStack(spacing: 32.vp) {
                    motionLabIntro(state, family, palette)
                    VStack(spacing: 16.vp) {
                        motionLabStage(state, family, palette)
                        motionLabActions(state)
                    }.hug().layoutWeight(1.0)
                }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
            } else {
                motionLabIntro(state, family, palette)
                motionLabStage(state, family, palette)
                motionLabActions(state)
            }
            FlowRow {
                Button(if (state.dark.value) {"Light palette"} else {"Dark palette"}, {=>
                    state.dark.value = !state.dark.value
                }).key("theme").buttonStyle(ButtonStyle.quiet())
                Button(if (state.reduced.value) {"Reduced motion: on"} else {"Reduced motion: off"}, {=>
                    state.reduced.value = !state.reduced.value
                }).key("reduced").buttonStyle(ButtonStyle.quiet())
            }.spacing(8.vp)
            Label("Explore a surface. Change a value. Give motion room to breathe.", fontSize: 12.fp)
                .muted().wrap().fillWidth()
        }.hug().fillWidth().padding(24.vp)
    }.fillWidth().fillHeight()
    ()
}

private func motionLabIntro(state: MotionLabState, family: KitMotionFamily, palette: KitMotionPalette): Unit {
    VStack(spacing: 18.vp) {
        Label("STUDY 0${state.family.value + 1}", color: palette.signal, fontSize: 11.fp).bold()
        Label(family.title(), fontSize: 36.fp).bold().wrap().fillWidth()
        Label(motionLabSummary(state.family.value), fontSize: 15.fp).muted().wrap().fillWidth()
        Label(motionLabDetail(state.family.value), fontSize: 12.fp).muted().wrap().fillWidth()
    }.hug().width(if (state.width.value >= 760.0) {(state.width.value - 80.0) * 0.34} else {state.width.value - 48.0})
        .probe("intro", "MotionStudyIntro")
    ()
}

private func motionLabStage(state: MotionLabState, family: KitMotionFamily, palette: KitMotionPalette): Unit {
    kitMotionStudy("stage", family, palette, replay: state.replay.value, value: state.number.value,
        shown: state.shown.value).height(340.vp).fillWidth()
}

private func motionLabActions(state: MotionLabState): Unit {
    FlowRow {
        Button("Replay", probedAction("replay", {=> state.repeat()})).key("replay")
        if (state.family.value == 1) {
            Button("9 → 10", probedAction("digits", {=>
                state.number.value = if (state.number.value == 9) {10} else {9}
            })).key("digits").buttonStyle(ButtonStyle.quiet())
            Button("Largest integer", {=> state.number.value = Int64.Max}).key("integer-limit")
                .buttonStyle(ButtonStyle.quiet())
        }
    }.spacing(8.vp)
    ()
}

private func motionLabSummary(index: Int64): String {
    match (index) {
        case 0 => "A quiet little drop, a few playful rebounds, and a precise landing."
        case 1 => "Numbers roll into place while a single scan reveals the incoming signal."
        case 2 => "A soft pool of light follows your pointer and rests with keyboard focus."
        case 3 => "Shared direction, staggered arrivals. Every part finds its own moment."
        case _ => "Fine rules, warm signals and a measured reveal make room for the details."
    }
}

private func motionLabDetail(index: Int64): String {
    match (index) {
        case 0 => "Replay to drop again. The scene rests after it lands."
        case 1 => "Try a digit boundary or the largest integer. The sign stays still."
        case 2 => "Move across the card, or focus Replay with the keyboard."
        case 3 => "Replay to reverse the sequence, even before it finishes."
        case _ => "Replay the archive opening. No timer runs after the reveal."
    }
}
