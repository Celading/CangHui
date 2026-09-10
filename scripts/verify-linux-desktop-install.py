#!/usr/bin/env python3
"""Opt-in native acceptance of a trusted CUIC SVG-icon fixture in a NEW prefix.

Not a production installer: requires Linux, Gtk3/GIO introspection, hicolor,
xdotool, xprop and an already-running X11 window manager. Never targets ~/.local
or a system directory implicitly. Keeps evidence; removal uses reversible rename.
"""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import time


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT, timeout=10).strip()


def fresh_discovery(identifier):
    # A fresh process prevents an in-process GIO cache from hiding stale entries.
    code = ('from gi.repository import Gio; import sys; '
            'print(int(sys.argv[1] in [item.get_id() for item in Gio.AppInfo.get_all()]))')
    return run(sys.executable, '-c', code, identifier + '.desktop') == '1'


def request_window_close(window):
    # XDestroyWindow invalidates the GL drawable under a live renderer. Request
    # normal application close via ICCCM WM_PROTOCOLS/WM_DELETE_WINDOW instead.
    class ClientMessage(ctypes.Structure):
        _fields_ = [('type', ctypes.c_int), ('serial', ctypes.c_ulong), ('send_event', ctypes.c_int),
                    ('display', ctypes.c_void_p), ('window', ctypes.c_ulong), ('message_type', ctypes.c_ulong),
                    ('format', ctypes.c_int), ('data', ctypes.c_long * 5)]
    class Event(ctypes.Union):
        _fields_ = [('client', ClientMessage), ('pad', ctypes.c_long * 24)]
    x11 = ctypes.CDLL('libX11.so.6')
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
    x11.XInternAtom.restype = ctypes.c_ulong
    x11.XSendEvent.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_long, ctypes.POINTER(Event)]
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    display = x11.XOpenDisplay(None)
    if not display:
        raise RuntimeError('cannot open test X11 display')
    try:
        protocols = x11.XInternAtom(display, b'WM_PROTOCOLS', 1)
        delete = x11.XInternAtom(display, b'WM_DELETE_WINDOW', 1)
        assert protocols and delete, 'window close protocol is unavailable'
        event = Event()
        event.client.type = 33  # ClientMessage
        event.client.display = display
        event.client.window = int(window)
        event.client.message_type = protocols
        event.client.format = 32
        event.client.data[0] = delete
        assert x11.XSendEvent(display, int(window), 0, 0, ctypes.byref(event)) != 0
        x11.XFlush(display)
    finally:
        x11.XCloseDisplay(display)


def verify(bundle, output):
    if sys.platform != 'linux':
        raise ValueError('native desktop acceptance requires Linux')
    bundle = bundle.resolve(strict=True)
    receipt_path = bundle / 'canghui-packaging-receipt.json'
    if receipt_path.is_symlink() or not receipt_path.is_file() or receipt_path.stat().st_size > 1024 * 1024:
        raise ValueError('requires a bounded regular packaging receipt')
    receipt = json.loads(receipt_path.read_text())
    if receipt['platform'] != 'linux' or not receipt['executableIncluded']:
        raise ValueError('requires a real CUIC Linux executable bundle, not a metadata-only tree')
    identifier = receipt['identity']['identifier']
    title = receipt['identity']['name']
    if not re.fullmatch(r'[A-Za-z0-9_.-]+', identifier) or not any(c.isalnum() for c in identifier):
        raise ValueError('unsafe application identifier')
    for path in bundle.rglob('*'):
        if path.is_symlink() or not (path.is_dir() or path.is_file()):
            raise ValueError('test accepts only regular bundle trees')
    output = output.absolute()
    output.mkdir()  # Exclusive: no reuse, overwrite or recursive cleanup of user data.
    prefix = output / 'private install prefix'
    app_root = prefix / 'lib' / identifier
    shutil.copytree(bundle, app_root)
    shutil.copytree(app_root / 'share', prefix / 'share')
    (prefix / 'bin').mkdir()
    wrapper = prefix / 'bin' / identifier
    wrapper.write_text('#!/bin/sh\nexec ' + shlex.quote(str(app_root / 'bin' / identifier)) + ' "$@"\n')
    wrapper.chmod(0o755)
    runtime = output / 'session'
    runtime.mkdir(mode=0o700)
    # Use a process-local desktop environment. No shell-profile or host change.
    os.environ['XDG_DATA_HOME'] = str(prefix / 'share')
    os.environ['XDG_RUNTIME_DIR'] = str(runtime)
    os.environ['PATH'] = str(prefix / 'bin') + ':' + os.environ['PATH']
    os.environ.pop('LD_LIBRARY_PATH', None)
    os.environ.pop('CANGHUI_CAPTURE_PATH', None)
    os.environ.pop('CANGHUI_CAPTURE_FRAMES', None)
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gio, Gtk
    app = Gio.DesktopAppInfo.new(identifier + '.desktop')
    if app is None or identifier + '.desktop' not in [item.get_id() for item in Gio.AppInfo.get_all()]:
        raise AssertionError('desktop app registry did not discover installed entry')
    assert app.should_show(), 'registered entry is hidden from application menus'
    icon_name = app.get_icon().to_string()
    assert icon_name == identifier, icon_name
    theme = Gtk.IconTheme.get_default()
    icons = []
    for size in (24, 48, 256):
        icon = theme.lookup_icon(icon_name, size, 0)
        assert icon is not None, (icon_name, size)
        path = Path(icon.get_filename()).resolve()
        assert path.is_relative_to(prefix / 'share'), path
        pixels = icon.load_icon()
        assert (pixels.get_width(), pixels.get_height()) == (size, size), 'fixture requires scalable SVG'
        icons.append({'requested': size, 'file': str(path), 'decoded': [pixels.get_width(), pixels.get_height()]})
    assert app.launch([], None), 'desktop registry launch rejected'
    window = ''
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        found = subprocess.run(['xdotool', 'search', '--onlyvisible', '--name', '^' + re.escape(title) + '$'],
                               text=True, capture_output=True, timeout=3)
        if found.returncode == 0:
            window = found.stdout.strip().splitlines()[-1]
            break
        time.sleep(.05)
    assert window, 'registry launch did not create a visible window'
    window_class = run('xprop', '-id', window, 'WM_CLASS')
    assert window_class.endswith('"' + identifier + '"'), window_class
    geometry = run('xdotool', 'getwindowgeometry', '--shell', window)
    request_window_close(window)
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if subprocess.run(['xdotool', 'getwindowname', window], capture_output=True, timeout=3).returncode != 0:
            break
        time.sleep(.05)
    else:
        raise AssertionError('native window remained visible after close')
    # Recoverable removal of this test-owned prefix only; no recursive deletion.
    removed = output / 'removed install prefix'
    prefix.rename(removed)
    assert not fresh_discovery(identifier), 'new process still discovers removed desktop entry'
    removed.rename(prefix)
    assert fresh_discovery(identifier), 'new process cannot discover restored desktop entry'
    report = {'schema': 'canghui.linux-desktop-install-test/v1', 'identifier': identifier,
              'bundleReceiptSha256': hashlib.sha256((bundle / 'canghui-packaging-receipt.json').read_bytes()).hexdigest(),
              'registryLaunch': True, 'nativeClass': window_class, 'geometry': geometry, 'icons': icons,
              'windowClosed': True, 'removedDiscoveryAbsent': True, 'restoredDiscoveryPresent': True,
              'processShutdownCertified': False, 'productionInstaller': False}
    (output / 'receipt.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True, help='new evidence directory under an existing parent')
    args = parser.parse_args()
    verify(args.bundle, args.output)
