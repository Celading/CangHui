package cuic

import std.collection.ArrayList

@Test
func cjpmProfileSelectsExactBuildAndTestMode(): Unit {
    @Expect(cjpmProfileArguments("build", "debug"), ["build", "-g"])
    @Expect(cjpmProfileArguments("test", "debug"), ["test", "-g"])
    @Expect(cjpmProfileArguments("build", "release"), ["build"])
    @Expect(cjpmProfileArguments("test", "release"), ["test"])
    let (selection, mode, jobs) = parseCjpmProfile(["mac", ".", "--mode", "debug"], 0)
    @Expect(selection.platform, "macos")
    @Expect(selection.project, currentDirectory())
    @Expect(mode, "debug")
    @Expect(jobs, Int64(0))
    let (_, defaultMode, _) = parseCjpmProfile(["."], 0)
    @Expect(defaultMode, "release")
    let (implicit, earlyMode, _) = parseCjpmProfile(["--mode", "release"], 0)
    @Expect(implicit.project, currentDirectory())
    @Expect(earlyMode, "release")
}

@Test
func cjpmJobsSelectsBoundedConcurrencyWithoutChangingDefaults(): Unit {
    let (_, mode, jobs) = parseCjpmProfile(["--jobs", "001", ".", "--mode", "debug"], 0)
    @Expect(mode, "debug")
    @Expect(jobs, Int64(1))
    @Expect(parseCjpmJobs("256"), Int64(256))
    @Expect(cjpmProfileArguments("build", mode, jobs: jobs), ["build", "-g", "-j", "1"])
    @Expect(cjpmProfileArguments("test", "release", jobs: 256), ["test", "-j", "256"])
    @Expect(sourceSdkBuildArguments(cjpmProfileArguments("test", "debug", jobs: 2)),
        ["test", "-g", "-j", "2"])
    @Expect(sourceSdkBuildArguments(cjpmProfileArguments("build", "release")), ["build", "-j", "1"])
    for (invalid in [-1, 257]) {
        var rejected = false
        try { let _ = cjpmProfileArguments("test", "debug", jobs: invalid) }
        catch (_: CuicError) { rejected = true }
        @Expect(rejected)
    }
}

@Test
func cjpmJobsRejectsInvalidOptionsBeforeProjectLookup(): Unit {
    for (action in ["build", "test", "run"]) {
        for (invalid in ["", "0", "-1", "+1", "257", "999999999999999999999", "1.5", " 1", "1 ", "１", "two"]) {
            var rejected = false
            try { let _ = runCuicInternal(["cuic", action, "/cuic-no-such-jobs-project", "--jobs", invalid], false) }
            catch (error: CuicError) { rejected = error.message.contains("--jobs") }
            @Expect(rejected)
        }
        for (suffix in [["--jobs"], ["--jobs", "1", "--jobs", "2"]]) {
            let args = ArrayList<String>()
            args.add("cuic"); args.add(action); args.add("/cuic-no-such-jobs-project")
            for (value in suffix) { args.add(value) }
            var rejected = false
            try { let _ = runCuicInternal(args.toArray(), false) }
            catch (error: CuicError) { rejected = error.message.contains("--jobs") }
            @Expect(rejected)
        }
    }
}

@Test
func cjpmProfileRejectsMissingDuplicateAndIgnoredOptions(): Unit {
    for (args in [[".", "--mode"], [".", "--mode", "fast"], [".", "--mod", "debug"],
        [".", "extra"], [".", "--mode", "debug", "--mode", "release"]]) {
        var rejected = false
        try { let _ = parseCjpmProfile(args, 0) }
        catch (_: CuicError) { rejected = true }
        @Expect(rejected)
    }
}
