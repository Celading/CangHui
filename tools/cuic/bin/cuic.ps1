param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CliArgs)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Binary = Join-Path $Root "target/release/bin/main.exe"

if (-not (Test-Path $Binary)) {
    Push-Location $Root
    try {
        & cjpm build
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    finally { Pop-Location }
}

$env:CANGHUI_CLI_ROOT = $Root
& $Binary @CliArgs
exit $LASTEXITCODE
