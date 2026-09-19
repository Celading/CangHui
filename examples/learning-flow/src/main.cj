package chui_learning_flow

import chui.*
import chui.kmode.macros.*

func lessonView(model: LessonModel): Unit {
    VStack {
        Row(space: 8.vp) {
            Label("詞語練習").bold().layoutWeight()
            Label("${model.score.value} XP").muted()
        }.hug()
        Divider()
        if (!model.started.value) {
            Label("每日一詞").fontSize(26.fp).bold()
            Label("先選擇答案，再查看結果。支持鍵盤與指針操作。").wrap()
            Button("開始", probedAction("lesson.start", {=> model.start()}),
                role: ButtonRole.Primary).key("lesson.start").fillWidth()
        } else if (model.finished.value) {
            Label("練習完成").fontSize(26.fp).bold()
            Label("本次 ${model.score.value} XP").wrap()
            Button("再試一次", probedAction("lesson.retry", {=> model.start()}))
                .key("lesson.retry").fillWidth()
        } else {
            Label("你好").fontSize(32.fp).bold()
            Label("nei5 hou2").muted()
            Label("選擇對應意思").wrap()
            Button("Hello", probedAction("lesson.correct", {=> model.answer(true)}))
                .key("lesson.correct").fillWidth()
            Button("Goodbye", probedAction("lesson.wrong", {=> model.answer(false)}))
                .key("lesson.wrong").fillWidth()
            if (model.answered.value) {
                Label(if (model.correct.value) { "答對了" } else { "再記一次：你好 = Hello" }).wrap()
                Button("查看結果", probedAction("lesson.finish", {=> model.finish()}),
                    role: ButtonRole.Primary).key("lesson.finish").fillWidth()
            }
        }
        Spacer()
    }.spacing(12.vp).padding(20.vp)
}

func lessonProbe(script: String, width: Float32): String {
    let model = LessonModel()
    ComponentProbe("learning.lesson", width: width, height: 600.0).run(script) {
        ProbeNode("lesson.state", widgetType: "Lesson", properties: [
            ProbeProperty("score", model.score.value.toString()),
            ProbeProperty("finished", model.finished.value.toString())
        ]) { lessonView(model) }
    }
}

@CuiProbe["learning.phone"]
func phoneProbe(script: String): String { lessonProbe(script, 360.0) }

@CuiProbe["learning.desktop"]
func desktopProbe(script: String): String { lessonProbe(script, 800.0) }

main(): Int64 {
    if (runKModeStdioIfRequested()) { return 0 }
    let model = LessonModel()
    let app = DesktopApp(WindowSpec("Learning flow", 480, 640,
        scaling: Some(WindowScaleSettings())))
    app.run { lessonView(model) }
    0
}
