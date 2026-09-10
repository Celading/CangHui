#!/usr/bin/env python3
"""Exercise CI child-env isolation and failure propagation without a native build."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    ci = Path(__file__).resolve().with_name("ci.sh")
    with tempfile.TemporaryDirectory(prefix="chui CI loader ") as temp:
        root = Path(temp)
        scripts = root / "scripts"
        scripts.mkdir()
        shutil.copy2(ci, scripts / "ci.sh")
        # Avoid recursive execution: the fixture exercises ci.sh, not this test.
        (scripts / "test-ci-loader-env.py").write_text("pass\n", encoding="utf-8")
        libs = root / "sdl" / ".sdl3"
        libs.mkdir(parents=True)
        for name in ("libSDL3.dylib", "libSDL3_ttf.dylib"):
            (libs / name).touch()
        for inherited in (None, "/opt/homebrew/lib:/unrelated/native"):
            env = dict(os.environ, CHUI_TEST_PRESERVE="retained")
            # Protected macOS shebang interpreters strip DYLD variables. Observe
            # inside the same shell rather than through a /bin/sh test shim.
            command = '''
if [[ -n "$2" ]]; then export DYLD_LIBRARY_PATH="$2"; else unset DYLD_LIBRARY_PATH; fi
cjpm() {
  printf 'CHUI_TEST_LOADER=%s\nCHUI_TEST_OTHER=%s\n' "$DYLD_LIBRARY_PATH" "$CHUI_TEST_PRESERVE"
  return 37
}
source "$1"
'''
            result = subprocess.run(["bash", "-c", command, "loader-test", str(scripts / "ci.sh"), inherited or ""], env=env,
                                    text=True, capture_output=True, check=False)
            assert result.returncode == 37, result.stdout + result.stderr
            records = [line for line in result.stdout.splitlines() if line.startswith("CHUI_TEST_")]
            assert len(records) == 2 and records[1] == "CHUI_TEST_OTHER=retained", records
            assert records[0].startswith("CHUI_TEST_LOADER="), records
            assert Path(records[0].split("=", 1)[1]).resolve() == libs.resolve(), records
            scoped_notice = "scoping the CI dynamic-library search path" in result.stdout
            assert scoped_notice == (inherited is not None), result.stdout
        print("CI loader environment: 2 cases passed; child failure preserved")


if __name__ == "__main__":
    main()
