# Thin Windows delivery

Entry: `cuic package installer windows --help`. Python 3.11+ is a build-time dependency.
No global NSIS/WiX discovery, downloads, updates or shell command hooks run here.

## Engine contract v1

Place a **trusted** engine in `delivery/engines/nsis` for source CUIC, or
`cuic-delivery/engines/nsis` next to an installed CUIC executable. An explicit `--engine-bundle`
overrides that location. HapCLI can supply the same directory contract without changing PATH.

```text
nsis/
  engine.json
  makensis                 # makensis.exe on Windows; native to the build host
  COPYING                  # exact upstream license notices
  Stubs/                   # matching upstream target templates
  Include/
  Contrib/
  Plugins/                 # default installer uses x86-unicode/System.dll
```

`engine.json` fields: `schema = chui.installer-engine.v1`, `version` (NSIS 3.x),
`host` (`darwin-arm64`, `linux-x86_64`, `win32-x86_64`, etc.), `files` (relative path → SHA-256).
The inventory includes every regular file except the manifest itself. Links, Windows reparse points,
case collisions, missing and extra files are rejected. Paths use `/`. Engine and payload inventories
are limited to 10000 entries (including directories) and 1 GiB each. The adapter accepts only x86/x64 application entries;
host support must not be confused with tested Windows targets.

Maintainers can seal an explicitly provisioned directory, after verifying upstream downloads:

```bash
python3 tools/cuic/delivery/seal_engine.py /trusted/engine --version 3.12 \
  --source-sha256 <64-hex-source-archive-digest> --templates-sha256 <64-hex-template-archive-digest>
python3 tools/cuic/delivery/bundle.py --cuic tools/cuic/target/release/bin/main \
  --engine /trusted/engine --output /new/cuic-delivery-bundle
```

Sealing records supplied provenance; it does not authenticate downloads. The pack provider must validate
the compiler, template version, host runtime closure, licensing and upstream hashes. POSIX NSIS compilers
can be built from upstream source and use matching official Windows ZIP stubs. Preserve `COPYING` and
all applicable notices. CUIC invokes the fixed compiler with `NOCONFIG`, a private working directory
and fixed arguments; arbitrary user-provided NSIS snippets are not included.

The bundle contains CUIC, helpers, a private engine and inventories. Test it outside the checkout with
no global `makensis` before distribution. A source-only sparse install carries helpers but no engine.
`scripts/install-cuic.sh --source ...` also carries a source pack's private engine when present.
No runtime/provider support is implied by generating a directory or EXE.

Tests: `python3 -m unittest discover -s tools/cuic/delivery -p 'test_*.py'`.
Real compiler replay: `python3 tools/cuic/delivery/smoke_real.py --engine /trusted/engine --entry /trusted/App.exe`.
This compiles both modes with Unicode/space resource names; it never runs the input EXE.
Native acceptance must additionally exercise install/cancel/duplicate install/uninstall, unknown-file
preservation, paths with spaces/Unicode, portable process exit/temporary cleanup, locked files, absent
runtime DLLs, and signing. See the [manual](../../../manual/reference/windows-installer.md).
