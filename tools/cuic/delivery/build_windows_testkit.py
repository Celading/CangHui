#!/usr/bin/env python3
"""Cross-build a four-case Windows packaging kit. No Windows execution is implied."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile
from installer import build, digest, inventory

GUIDE = """# canghui-package Windows 真机测试

本包包含四个可执行程序：普通/Honor × 安装/便携。目标 Windows x64。
这是原生 C GUI 打包夹具，验证安装引擎，不代表仓颉或仓绘完整运行时已通过 Windows 验收。
测试包未签名：仅在核验来源与 SHA256 后自行决定运行，不需要关闭系统安全功能。

1. 解压到含空格或中文的目录。先核对 SHA256SUMS.txt；无管理员权限运行。
2. normal-portable 与 honor-portable：均应显示 GUI、Unicode resource PASS 和实际执行路径，
   不弹控制台。记录对话框中的临时路径，关闭后确认这个应用专属临时目录清理。
   在 PowerShell 使用 Start-Process -Wait -PassThru 观察 ExitCode：Yes 为0，No 为7。
3. normal-install 与 honor-install：先取消，应无安装；再同意，应安装到当前用户的
   LOCALAPPDATA/Programs/dev.chui.packagetest.normal（或honor）/1.0.0，并有开始菜单入口。
   从入口启动，确认两项 PASS；重复安装同版本应拒绝。
4. 在安装目录手工放一个 keep-me.txt，再运行 Uninstall.exe：应用文件、快捷方式与卸载项
   应移除，keep-me.txt 应保留。此人为测试文件最后由你自行清理。
5. 使用自己的7-Zip按NSIS格式尝试解包：普通包应可列出app.exe，Honor包应拒绝标准识别。
   Honor只是归档头混淆，不是加密；定制解包器、运行时临时文件仍能提取内容。
6. 回传系统版本、各步骤结果、ExitCode和失败截图。没有实机结果前不将回执改为已通过。

不自删源程序、不提升权限、不连接网络。便携缓存只放系统临时目录；崩溃、断电或锁定文件时
自动清理只能尽力完成。应用持久缓存应明确用途与位置并尽可能取得用户授权。

每个目录内 receipt.json 是编译事实，windowsExecutionVerified=false。NSIS-COPYING.txt
保留底层许可。source/windows_smoke.c 提供夹具源码。
"""


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--engine", required=True)
    p.add_argument("--compiler", required=True, help="trusted x86_64 Windows C compiler path")
    p.add_argument("--output", required=True, type=Path)
    a = p.parse_args()
    out = a.output.absolute()
    out.mkdir(parents=True, exist_ok=False)
    source = Path(__file__).parent / "windows_smoke.c"
    with tempfile.TemporaryDirectory(prefix="chui-windows-kit-") as temp:
        work = Path(temp)
        payload = work / "payload"
        (payload / "resources").mkdir(parents=True)
        (payload / "resources/空间 fixture.txt").write_bytes(b"canghui-package fixture\n")
        subprocess.run([a.compiler, str(source), "-municode", "-mwindows", "-static", "-Os", "-s",
                        "-o", str(payload / "app.exe")], check=True, timeout=60)
        for honor in (False, True):
            profile = "honor" if honor else "normal"
            (work / "canghui.toml").write_text('[application]\nname="CangHui Package Test ' + profile +
                '"\nidentifier="dev.chui.packagetest.' + profile + '"\nversion="1.0.0"\n')
            for mode in ("install", "portable"):
                name = profile + "-" + mode
                build(argparse.Namespace(project=str(work), payload="payload", entry="app.exe", mode=mode,
                    output=name, engine_bundle=a.engine, honor_system=honor))
                shutil.copytree(work / name, out / name)
    (out / "source").mkdir()
    shutil.copyfile(source, out / "source/windows_smoke.c")
    (out / "README.md").write_text(GUIDE, encoding="utf-8-sig")
    (out / "SHA256SUMS.txt").write_text("".join(f"{sha}  {path}\n" for path, sha in inventory(out).items()))
    archive = out.with_suffix(".zip")
    with zipfile.ZipFile(archive, "x", zipfile.ZIP_DEFLATED) as z:
        for path in sorted(out.rglob("*")):
            if path.is_file():
                z.write(path, str(Path(out.name) / path.relative_to(out)))
    print(json.dumps({"zip": str(archive), "sha256": digest(archive), "windowsExecutionVerified": False}))


if __name__ == "__main__":
    main()
