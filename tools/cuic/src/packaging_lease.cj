package cuic

// Output and target ownership are independent: callers may select different
// target directories but still request the same final artifact. Never wait on
// another lease or steal it; report contention and release only our own lease.
func withPackagingOutputLease(project: String, output: String, action: () -> Int64): Int64 {
    let context = ExecutionContext(project, "", targetDir: output, stagingRoot: project)
    let lease = context.acquireLease()
    try {
        // Check after ownership is established, not before a long build.
        ensurePackagingDestinationAvailable(output)
        action()
    } finally { context.releaseLease(lease) }
}

func withPackagingBuildLease(context: ExecutionContext, build: () -> Int64, consume: () -> Int64): Int64 {
    let lease = context.acquireLease()
    try {
        let code = build()
        if (code != 0) { return code }
        // Copy, relocation, hardening, audit and receipt all consume this exact
        // build while its target remains unavailable to cooperating CUIC jobs.
        consume()
    } finally { context.releaseLease(lease) }
}
