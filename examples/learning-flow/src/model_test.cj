package chui_learning_flow

@Test
func answerRequiresActiveLesson(): Unit {
    let model = LessonModel()
    model.answer(true)
    model.finish()
    @Expect(model.score.value, Int64(0))
    @Expect(!model.finished.value)
}

@Test
func duplicateAnswerDoesNotDuplicateReward(): Unit {
    let model = LessonModel()
    model.start()
    model.answer(true)
    model.answer(true)
    model.finish()
    model.answer(true)
    @Expect(model.score.value, Int64(10))
    @Expect(model.finished.value)
    model.start()
    @Expect(model.score.value, Int64(0))
    @Expect(!model.answered.value)
}

@Test
func wrongAnswerRemainsWrongUntilRetry(): Unit {
    let model = LessonModel()
    model.start()
    model.answer(false)
    model.answer(true)
    @Expect(!model.correct.value)
    @Expect(model.score.value, Int64(0))
    model.finish()
    @Expect(model.finished.value)
}
