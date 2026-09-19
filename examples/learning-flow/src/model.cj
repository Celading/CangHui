package chui_learning_flow

import chui.State

class LessonModel {
    let started = State<Bool>(false)
    let answered = State<Bool>(false)
    let correct = State<Bool>(false)
    let finished = State<Bool>(false)
    let score = State<Int64>(0)

    func start(): Unit {
        started.value = true
        answered.value = false
        correct.value = false
        finished.value = false
        score.value = 0
    }

    func answer(value: Bool): Unit {
        if (!started.value || answered.value || finished.value) { return }
        correct.value = value
        answered.value = true
        if (value) { score.value += 10 }
    }

    func finish(): Unit {
        if (started.value && answered.value) { finished.value = true }
    }
}
