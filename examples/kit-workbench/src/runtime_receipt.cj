package canghui_kit_workbench

// Read-only acceptance output. No environment, event injection or release channel.
@When[debug]
func workbenchResult(state: WorkbenchState, appliedDark: Bool, appliedReduced: Bool): String {
    "{\"protocol\":\"canghui.kit-workbench-result.v1\",\"profile\":${state.profile.value}," +
    "\"selected\":${state.selected.value},\"starts\":${state.starts.value},\"holds\":${state.holds.value}," +
    "\"expanded\":${state.expanded.value},\"dark\":${state.dark.value},\"reduced\":${state.reduced.value}," +
    "\"appliedDark\":${appliedDark},\"appliedReduced\":${appliedReduced}}"
}

@When[debug]
func emitWorkbenchResult(state: WorkbenchState, appliedDark: Bool, appliedReduced: Bool): Unit {
    println("KIT_WORKBENCH_RESULT " + workbenchResult(state, appliedDark, appliedReduced))
}

@When[!debug]
func emitWorkbenchResult(_: WorkbenchState, _: Bool, _: Bool): Unit {}
