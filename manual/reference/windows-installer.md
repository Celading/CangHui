# Windows installers and portable applications

[中文](windows-installer.zh-CN.md)

CUIC provides a thin, offline EXE packaging adapter. A delivery bundle carries the private canghui-package engine (NSIS-backed);
NSIS/WiX need not be globally installed. A plain source installation includes the adapter, not native
engine binaries. The build host needs Python 3.11+; end users do not need Python, CUIC or NSIS.

Prepare an independently tested Windows application directory, including Cangjie runtime DLLs,
native dependencies, fonts and resources. The entry must be an x86/x64 PE executable.
Application identity comes from `[application]` in `canghui.toml`.

```bash
cuic package installer windows . --payload payload --entry App.exe --output dist/setup
cuic package installer windows . --payload payload --entry App.exe --mode portable --output dist/portable
# Optional explicit, trusted engine pack:
cuic package installer windows . --payload payload --entry App.exe --output dist/custom --engine-bundle /trusted/canghui-package
```

Output must not exist. The result includes an EXE, NSIS script, engine license and `receipt.json`.
Compilation, payload hashes, architecture, signing and Windows execution are separate receipt fields.
The adapter neither creates MSI files nor signs artifacts, downloads tools or verifies every runtime dependency.

Install mode uses native confirmation/progress UI and a fixed per-user directory under
`LocalAppData/Programs/<identifier>/<version>`, a Start menu shortcut and an HKCU uninstall entry.
Existing version directories are refused; `/S` does not bypass consent. Upgrades and rollback are not
implemented. Failed installation may leave partial output for inspection. Uninstall deletes only the
listed application files and generated entries, then removes empty directories without recursive deletion.
Unknown files are retained. Do not store user documents inside the installation tree.

Portable mode extracts into an exclusive OS temporary directory using NSIS `InitPluginsDir`, runs
the entry through `ExecWait`, and cleans up on launcher exit. Use the OS temp root (usually system
`/tmp` or its platform-managed equivalent; Windows Temp), not an invented persistent user directory.
Persistent caching should explain its purpose/location and obtain appropriate user authorization.
Never delete the whole temp root or the downloaded source EXE. Cleanup is best-effort, not secure erasure:
crashes, power loss and locked files may leave residue. `ExecWait` does not track detached descendants.
Keep the entry alive while children need extracted files, or provide your own process supervision.
Application arguments are not forwarded in this first adapter.

The default engine lives beside the adapter under `engines/canghui-package`; global tools are not searched.
HapCLI owns external tool discovery/provisioning. See the [engine contract](../../tools/cuic/delivery/README.md)
for offline packs and `bundle.py`. Hash verification detects corruption, not a malicious publisher.
Host runtime closure, native platform acceptance and distribution signing remain separate requirements.

`--honor-system` selects the paired `chui-honor-v1` compiler/reader profile: four archive-header
identifiers change, hiding the standard NSIS archive signature from unmodified NSIS extractors.
Missing paired profiles fail closed. PE loader headers, CRC and upstream license notices remain intact;
sign the finished output. This is optional format obfuscation, **not encryption or unextractability**.
Adapted tools, debuggers and runtime temporary files can still recover the payload. Receipts distinguish
`headerObfuscation` from `extractionProtection=false`. Never store secrets in a client package.

For advanced custom installer UI, enterprise MSI, updating, rollback, services or self-deleting launchers,
connect an application-owned backend. Keep UI separate from installation transactions. Generated scripts
may be adapted, but modified outputs need fresh compilation, signing and acceptance; old receipts do not apply.
