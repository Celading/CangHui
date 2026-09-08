[chui](../../index.md) › [chui.core](index.md) › UiTaskScope

# UiTaskScope

UiTaskScope 在已有 UiOwnerQueue 上提供有界的后台准备生命周期。prepare 在 worker 执行并返回不可变结果；apply 通过 owner queue 回到 UI owner，才允许修改 State 或组件。

```cangjie
let queue = UiOwnerQueue() // 自定义宿主负责在 UI 线程 drain 和关闭队列。
let scope = UiTaskScope("app.search", queue,
    policy: UiTaskPolicy.LatestOnly)

let ticket = scope.submit(
    {=> buildSearchResult(query) },
    {result => results.value = result},
    surfaceGeneration: Some(windowGeneration)
)
```

UiTaskPolicy 支持 SingleFlight、LatestOnly、Queue(limit) 与 Debounce(ms)。取消是协作式的：它阻止未领取的 owner apply，但不会强杀已经运行的外部函数。close 会取消未完成任务并永久拒绝新提交，不会关闭共享 UiOwnerQueue。

UiTaskSubmission.status() 在进入 owner queue 后映射原有 UiOwnerReceipt；过期 epoch 或 surface generation 统一呈现为 RejectedStaleOwner。框架不会替业务做重试、事务回滚、进程管理或协议策略。

## 随视图卸载取消

视图拥有的任务使用 `rememberUiTaskScope`，不要仅把作用域放进普通
`rememberState` 后期待自动清理。在活动构建中取得作用域，在交互回调中提交工作：

```cangjie
app.run {
    if (showSearch.value) {
        let scope = app.rememberTaskScope("search.load",
            policy: UiTaskPolicy.LatestOnly)
        Button("搜索", {=>
            let query = searchText.value
            let _ = scope.submit({=> search(query)}, {result => results.value = result})
        })
    }
}
```

`DesktopApp.rememberTaskScope` 绑定应用内部队列，只能在该应用的构建中调用，不公开
队列的 drain/close 权限。自定义宿主用 `rememberUiTaskScope(key, queue, policy:)`。

作用域沿用 StateStore 和 `Keyed` 的身份规则，在重建间保留。视图成功卸载、存储清空
或新建条目所属的构建回滚时，框架调用 `close()`。取消的 retained frame 不会误关
上一个已提交视图的任务。卸载后重挂同一个 key 会创建新的作用域。

同一个 key 的队列与任务策略必须保持不变，否则会报错；需要变更时使用新的 key。
重复 key、与普通 remembered state 的 key 冲突、在构建之外调用也会报错。手动关闭
是终止操作，重建不会自动重新打开该实例。共享 UiOwnerQueue 不随视图关闭。

只有这个专用入口拥有自动清理权；普通 `rememberState` 中的任务、资源或共享对象
仍由调用方管理。取消阻止尚未应用的结果，不会强杀后台函数或回滚已完成的副作用。
