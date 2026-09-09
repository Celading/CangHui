package cuic

import std.fs.{Directory, File, SymbolicLink, removeIfExists}

@Test
func integratedFrameworkIdentityCanonicalizesRelativeCliRoot(): Unit {
    let root = integratedFrameworkRoot()
    @Expect(!root.isEmpty())
    @Expect(integratedFrameworkRootAt(".", currentDirectory()), root)
    @Expect(integratedFrameworkRootAt(joinPath(root, "tools/cuic/./"), currentDirectory()), root)
    @Expect(integratedFrameworkRootAt("tools/cuic", root), root)
    @Expect(integratedFrameworkRootAt("", root), root)
    @Expect(integratedFrameworkRootAt("missing-cli", root), root)
}

@Test
func integratedContainmentUsesResolvedDirectoryIdentity(): Unit {
    let relative = "target/framework-identity-${currentPid()}"
    let fixture = joinPath(currentDirectory(), relative)
    let integrated = joinPath(fixture, "framework")
    let inside = joinPath(integrated, "sub")
    let outside = joinPath(fixture, "framework-other")
    Directory.create(inside, recursive: true)
    Directory.create(outside, recursive: true)
    try {
        @Expect(integratedFrameworkContainsProject(inside, integrated))
        @Expect(integratedFrameworkContainsProject(integrated, integrated))
        @Expect(integratedFrameworkContainsProject(relative + "/framework/sub", integrated))
        @Expect(integratedFrameworkContainsProject(inside, relative + "/framework"))
        @Expect(!integratedFrameworkContainsProject(outside, integrated))
        @Expect(!integratedFrameworkContainsProject(integrated + "/../framework-other", integrated))
        @Expect(!integratedFrameworkContainsProject(inside, ""))
        @Expect(!integratedFrameworkContainsProject("", integrated))
        if (hostPlatform() != "windows") {
            let escape = joinPath(integrated, "escape")
            SymbolicLink.create(escape, to: outside)
            @Expect(!integratedFrameworkContainsProject(escape, integrated))
            _ = removeIfExists(escape)
        }
    } finally {
        _ = removeIfExists(fixture, recursive: true)
    }
}

@Test
func integratedProjectsStillEnforceDeclaredGitLocks(): Unit {
    let fixture = joinPath(currentDirectory(), "target/framework-lock-${currentPid()}")
    Directory.create(fixture, recursive: true)
    try {
        File.writeTo(joinPath(fixture, "cjpm.toml"),
            ("[package]\nname = \"fixture\"\n[dependencies]\n" +
            "chui = { git = \"https://example.invalid/chui.git\", commitId = \"abc123\" }\n").toArray())
        var rejected = false
        try { requireFrozenFrameworkDependency(fixture) }
        catch (error: CuicError) { rejected = error.message.contains("lock is missing") }
        @Expect(rejected)
        File.writeTo(joinPath(fixture, "cjpm.lock"),
            "[requires]\nchui = { commitId = \"abc123\" }\n".toArray())
        requireFrozenFrameworkDependency(fixture)
    } finally {
        _ = removeIfExists(fixture, recursive: true)
    }
}
