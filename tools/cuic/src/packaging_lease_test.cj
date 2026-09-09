package cuic

import std.fs.{Directory, File, exists, removeIfExists}
import std.collection.ArrayList

private func packagingLeaseRejects(action: () -> Unit): Bool {
    try { action(); false } catch (_: Exception) { true }
}

private func packagingLeaseFixture(name: String): String {
    let root = joinPath(currentDirectory(), "target/packaging-lease-" + name)
    if (exists(root)) { throw CuicError("packaging lease fixture already exists") }
    Directory.create(root, recursive: true)
    root
}

private func expectPackagingTargetBusy(context: ExecutionContext): Unit {
    @Expect(packagingLeaseRejects({=>
        let unexpected = context.acquireLease()
        context.releaseLease(unexpected)
    }))
}

@Test
func packagingTargetStaysOwnedUntilReceiptConsumptionFinishes(): Unit {
    let root = packagingLeaseFixture("whole-flow")
    let context = ExecutionContext(root, root, targetDir: joinPath(root, "build"), stagingRoot: root)
    let output = joinPath(root, "App.app")
    let stages = ArrayList<String>()
    try {
        let result = withPackagingOutputLease(root, output, {=>
            withPackagingBuildLease(context, {=>
                stages.add("build;")
                expectPackagingTargetBusy(context)
                0
            }, {=>
                for (stage in ["copy;", "relocate;", "audit;", "receipt;"]) {
                    stages.add(stage)
                    expectPackagingTargetBusy(context)
                    @Expect(exists(output + ".cuic-lease"))
                }
                7
            })
        })
        @Expect(result, 7)
        @Expect(stages.toArray(), ["build;", "copy;", "relocate;", "audit;", "receipt;"])
        @Expect(!exists(context.targetDir + ".cuic-lease"))
        @Expect(!exists(output + ".cuic-lease"))
    } finally { removeIfExists(root, recursive: true) }
}

@Test
func packagingFailedBuildNeverConsumesOldExecutableAndReleasesBothLeases(): Unit {
    let root = packagingLeaseFixture("failed-build")
    let context = ExecutionContext(root, root, targetDir: joinPath(root, "build"), stagingRoot: root)
    let output = joinPath(root, "App.app")
    let consumed = ArrayList<Bool>()
    try {
        @Expect(withPackagingOutputLease(root, output, {=>
            withPackagingBuildLease(context, {=> 23}, {=> consumed.add(true); 0 })
        }), 23)
        @Expect(consumed.isEmpty())
        @Expect(!exists(context.targetDir + ".cuic-lease"))
        @Expect(!exists(output + ".cuic-lease"))
    } finally { removeIfExists(root, recursive: true) }
}

@Test
func packagingExceptionsAtEveryStageReleaseTargetAndOutputWithoutErasingCandidate(): Unit {
    let root = packagingLeaseFixture("exceptions")
    let context = ExecutionContext(root, root, targetDir: joinPath(root, "build"), stagingRoot: root)
    let output = joinPath(root, "App.app")
    try {
        for (stage in ["build", "copy", "audit", "receipt"]) {
            @Expect(packagingLeaseRejects({=>
                let _ = withPackagingOutputLease(root, output, {=>
                    withPackagingBuildLease(context, {=>
                        if (stage == "build") { throw CuicError("injected build failure") }
                        0
                    }, {=>
                        Directory.create(output)
                        File.writeTo(joinPath(output, "failed-stage"), stage.toArray())
                        throw CuicError("injected " + stage + " failure")
                    })
                })
            }))
            @Expect(!exists(context.targetDir + ".cuic-lease"))
            @Expect(!exists(output + ".cuic-lease"))
            if (stage != "build") {
                @Expect(String.fromUtf8(File.readFrom(joinPath(output, "failed-stage"))), stage)
                removeIfExists(output, recursive: true)
            }
        }
    } finally { removeIfExists(root, recursive: true) }
}

@Test
func packagingBusyTargetCannotReleaseTheOtherOwnersLease(): Unit {
    let root = packagingLeaseFixture("busy-target")
    let context = ExecutionContext(root, root, targetDir: joinPath(root, "build"), stagingRoot: root)
    let output = joinPath(root, "App.app")
    let owner = context.acquireLease()
    let built = ArrayList<Bool>()
    try {
        @Expect(packagingLeaseRejects({=>
            let _ = withPackagingOutputLease(root, output, {=>
                withPackagingBuildLease(context, {=> built.add(true); 0}, {=> 0})
            })
        }))
        @Expect(built.isEmpty())
        @Expect(exists(joinPath(owner, "owner.txt")))
        @Expect(!exists(output + ".cuic-lease"))
    } finally { context.releaseLease(owner); removeIfExists(root, recursive: true) }
}

@Test
func packagingOutputOwnershipIsIndependentOfBuildTargetAndProtectsMetadataRoutes(): Unit {
    let root = packagingLeaseFixture("same-output")
    let output = joinPath(root, "App.app")
    let entered = ArrayList<Bool>()
    try {
        @Expect(withPackagingOutputLease(root, output, {=>
            @Expect(packagingLeaseRejects({=>
                let _ = withPackagingOutputLease(root, output, {=> entered.add(true); 0})
            }))
            @Expect(exists(joinPath(output + ".cuic-lease", "owner.txt")))
            0
        }), 0)
        @Expect(entered.isEmpty())
        Directory.create(output)
        let file = joinPath(output, "existing-artifact")
        File.writeTo(file, "preserve".toArray())
        @Expect(packagingLeaseRejects({=>
            let _ = withPackagingOutputLease(root, output, {=> entered.add(true); 0})
        }))
        @Expect(entered.isEmpty())
        @Expect(!exists(output + ".cuic-lease"))
        @Expect(String.fromUtf8(File.readFrom(file)), "preserve")
    } finally { removeIfExists(root, recursive: true) }
}
