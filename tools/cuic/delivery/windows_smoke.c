/* CangHui packaging fixture. This tests delivery, not the Cangjie GUI runtime. */
#ifndef UNICODE
#define UNICODE
#endif
#define _UNICODE
#include <windows.h>
#include <wchar.h>
#include <string.h>

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, PWSTR args, int show) {
    wchar_t exe[32768], resource[32768], message[34000];
    (void)instance; (void)previous; (void)args; (void)show;
    DWORD size = GetModuleFileNameW(NULL, exe, 32768);
    if (!size || size >= 32768) return 11;
    wcscpy(resource, exe);
    wchar_t *slash = wcsrchr(resource, L'\\');
    if (!slash) return 12;
    *slash = 0;
    if (wcslen(resource) + 40 >= 32768) return 13;
    wcscat(resource, L"\\resources\\空间 fixture.txt");
    HANDLE file = CreateFileW(resource, GENERIC_READ, FILE_SHARE_READ, NULL,
                              OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    char content[64] = {0};
    DWORD read = 0;
    BOOL ok = file != INVALID_HANDLE_VALUE && ReadFile(file, content, 63, &read, NULL);
    if (file != INVALID_HANDLE_VALUE) CloseHandle(file);
    if (!ok || read != 24 || memcmp(content, "canghui-package fixture\n", 24) != 0) {
        MessageBoxW(NULL, L"Bundled Unicode-path resource failed validation.", L"canghui-package", MB_OK|MB_ICONERROR);
        return 14;
    }
    swprintf(message, 34000, L"GUI launch: PASS\nUnicode resource: PASS\n\nExecutable:\n%ls\n\n"
        L"This is a native packaging fixture, not a CangHui UI runtime test.\n"
        L"Yes: exit 0. No: exit 7 (portable exit-code test).\n"
        L"Portable mode should remove its private temporary directory after closing.", exe);
    return MessageBoxW(NULL, message, L"canghui-package Windows Test", MB_YESNO|MB_ICONINFORMATION) == IDYES ? 0 : 7;
}
