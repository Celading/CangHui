#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-simulator}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_ROOT="${2:-${PROJECT_ROOT}/target/ios-widget-runtime}"
CANGJIE_IOS_HOME="${CANGJIE_IOS_HOME:-${CANGHUI_IOS_HOME:-}}"
DEPLOYMENT_TARGET="${CANGHUI_IOS_DEPLOYMENT_TARGET:-13.0}"
EXECUTABLE_NAME="CangHuiWidgetRuntime"
EXPECTED_RESULT="CANGHUI_IOS_WIDGETS result passed=1"

# shellcheck source=scripts/lib/ios-provisioning-profile.sh
source "${PROJECT_ROOT}/scripts/lib/ios-provisioning-profile.sh"

if [[ -z "${CANGJIE_IOS_HOME}" ]]; then
    printf 'Set CANGJIE_IOS_HOME to a Cangjie SDK with iOS targets.\n' >&2
    exit 1
fi

mkdir -p "${OUTPUT_ROOT}"
MODULE_ROOT="${OUTPUT_ROOT}/module"
STUB_SHIM="${OUTPUT_ROOT}/host-cjc"
BUILD_DIR="${OUTPUT_ROOT}/${MODE}"
APP_DIR="${BUILD_DIR}/${EXECUTABLE_NAME}.app"
LOG_FILE="${OUTPUT_ROOT}/${MODE}-console.log"
SHIM_CJC="${STUB_SHIM}/cjc"

prepare_host_shim() {
    local host_cjc
    local host_root
    host_cjc="$(command -v cjc)"
    host_root="$(cd "$(dirname "${host_cjc}")/.." && pwd)"
    mkdir -p "${STUB_SHIM}"
    cat > "${SHIM_CJC}" <<SHIM
#!/bin/sh
exec "${host_cjc}" --sysroot "$(xcrun --show-sdk-path)" \
    --link-option -rpath \
    --link-option "${host_root}/runtime/lib/darwin_aarch64_cjnative" "\$@"
SHIM
    chmod +x "${SHIM_CJC}"
}

build_module() {
    local target="$1"
    rm -rf "${MODULE_ROOT}"
    prepare_host_shim
    (
        cd "${PROJECT_ROOT}"
        PATH="${STUB_SHIM}:${PATH}" CANGJIE_HOME="${CANGJIE_IOS_HOME}" \
            "${CANGJIE_IOS_HOME}/tools/bin/cjpm" build \
            --target "${target}" --target-dir "${MODULE_ROOT}"
    )
}

repository_dir() {
    local target="$1"
    printf '%s\n' "${MODULE_ROOT}/${target}/release"
}

generate_stubs() {
    local repo="$1"
    local stub="$2"
    {
        printf '/* Link-only stubs: the recording renderer never calls SDL. */\n'
        nm -u "${repo}"/chui/*.a "${repo}"/sdl/*.a 2>/dev/null |
            grep -oE "_(SDL|TTF|IMG|Mix)_[A-Za-z0-9_]+" |
            sort -u |
            while read -r symbol; do
                printf 'void %s (void) {}\n' "${symbol#_}"
            done
    } > "${stub}"
}

compile_app() {
    local kind="$1"
    local sdk="$2"
    local repo="$3"
    local bundle_id="$4"
    local clang
    local sdk_path
    local minimum_flag
    clang="$(xcrun --sdk "${sdk}" --find clang)"
    sdk_path="$(xcrun --sdk "${sdk}" --show-sdk-path)"
    if [[ "${kind}" == "simulator" ]]; then
        minimum_flag="-mios-simulator-version-min=${DEPLOYMENT_TARGET}"
    else
        minimum_flag="-miphoneos-version-min=${DEPLOYMENT_TARGET}"
    fi
    rm -rf "${BUILD_DIR}"
    mkdir -p "${APP_DIR}" "${BUILD_DIR}/modules"
    cp "${PROJECT_ROOT}/platform/ios/widgets/Info.plist" "${APP_DIR}/Info.plist"
    plutil -replace CFBundleIdentifier -string "${bundle_id}" "${APP_DIR}/Info.plist"

    for source in \
        "${PROJECT_ROOT}/platform/ios/bootstrap/CangHuiRuntimeBootstrap.m" \
        "${PROJECT_ROOT}/platform/ios/runtime/CangHuiUIKitHostView.m" \
        "${PROJECT_ROOT}/platform/ios/runtime/CangHuiMetalSurfaceView.m" \
        "${PROJECT_ROOT}/platform/ios/runtime/CangHuiDisplayLinkDriver.m" \
        "${PROJECT_ROOT}/platform/ios/runtime/CangHuiNativeSceneSurfaceView.m" \
        "${PROJECT_ROOT}/platform/ios/widgets/AppDelegate.m"
    do
        "${clang}" -arch arm64 "${minimum_flag}" -isysroot "${sdk_path}" \
            -fobjc-arc -fblocks -fmodules \
            -fmodules-cache-path="${BUILD_DIR}/modules" \
            -I "${PROJECT_ROOT}/platform/ios/include" \
            -c "${source}" -o "${BUILD_DIR}/$(basename "${source%.m}").o"
    done

    local stubs="${BUILD_DIR}/sdl_stubs.c"
    generate_stubs "${repo}" "${stubs}"
    "${clang}" -arch arm64 "${minimum_flag}" -isysroot "${sdk_path}" \
        -c "${stubs}" -o "${BUILD_DIR}/sdl_stubs.o"

    local -a loads=()
    local archive
    for archive in "${repo}"/chui/*.a; do
        loads+=("-Wl,-force_load,${archive}")
    done
    for archive in "${repo}"/sdl/*.a; do
        loads+=("-Wl,-force_load,${archive}")
    done
    local runtime_dir="${CANGJIE_IOS_HOME}/lib/ios_simulator_aarch64_cjnative"
    if [[ "${kind}" == "device" ]]; then
        runtime_dir="${CANGJIE_IOS_HOME}/lib/ios_aarch64_cjnative"
    fi
    "${clang}" -arch arm64 "${minimum_flag}" -isysroot "${sdk_path}" \
        "${BUILD_DIR}/AppDelegate.o" \
        "${BUILD_DIR}/CangHuiRuntimeBootstrap.o" \
        "${BUILD_DIR}/CangHuiUIKitHostView.o" \
        "${BUILD_DIR}/CangHuiMetalSurfaceView.o" \
        "${BUILD_DIR}/CangHuiDisplayLinkDriver.o" \
        "${BUILD_DIR}/CangHuiNativeSceneSurfaceView.o" \
        "${BUILD_DIR}/sdl_stubs.o" \
        "${loads[@]}" \
        "${runtime_dir}/section.o" "${runtime_dir}/cjstart.o" \
        "${runtime_dir}"/libcangjie-std-*.a \
        "${runtime_dir}/libcangjie-runtime.a" \
        "${runtime_dir}/libboundscheck-static.a" \
        "${runtime_dir}/libcangjie-thread.a" \
        -framework UIKit -framework Foundation -framework QuartzCore -framework Metal \
        -lc++ -Wl,-no_compact_unwind \
        -o "${APP_DIR}/${EXECUTABLE_NAME}"
}

wait_for_result() {
    local log_file="$1"
    local launch_pid="$2"
    local attempts=0
    while (( attempts < 600 )); do
        if grep -Fq "${EXPECTED_RESULT}" "${log_file}"; then
            kill "${launch_pid}" >/dev/null 2>&1 || true
            wait "${launch_pid}" >/dev/null 2>&1 || true
            cat "${log_file}"
            printf 'CangHui iOS widget runtime passed.\n'
            return 0
        fi
        if ! kill -0 "${launch_pid}" >/dev/null 2>&1; then break; fi
        sleep 0.1
        attempts=$((attempts + 1))
    done
    kill "${launch_pid}" >/dev/null 2>&1 || true
    wait "${launch_pid}" >/dev/null 2>&1 || true
    cat "${log_file}" >&2
    printf 'Expected widget-runtime result was not observed: %s\n' "${EXPECTED_RESULT}" >&2
    return 1
}

verify_simulator() {
    local bundle_id="${CANGHUI_IOS_WIDGET_SIMULATOR_BUNDLE_ID:-dev.canghui.widget.runtime}"
    local device="${CANGHUI_IOS_SIMULATOR_DEVICE:-booted}"
    local target="aarch64-apple-ios-simulator"
    build_module "${target}"
    local repo
    repo="$(repository_dir "${target}")"
    if [[ "${device}" == "booted" ]]; then
        if ! xcrun simctl list devices available | grep -q '(Booted)'; then
            device="$(xcrun simctl list devices available |
                awk -F '[()]' '/^[[:space:]]+.*\([0-9A-F-]+\) \((Shutdown|Booted)\)/ { print $2; exit }')"
        fi
    fi
    if [[ "${device}" != "booted" ]]; then
        xcrun simctl boot "${device}" >/dev/null 2>&1 || true
        xcrun simctl bootstatus "${device}" -b >&2
    fi
    compile_app simulator iphonesimulator "${repo}" "${bundle_id}"
    xcrun simctl install "${device}" "${APP_DIR}"
    : > "${LOG_FILE}"
    xcrun simctl launch --terminate-running-process --console "${device}" "${bundle_id}" \
        >"${LOG_FILE}" 2>&1 &
    wait_for_result "${LOG_FILE}" "$!"
}

find_valid_provisioning_profile() {
    local bundle_id="$1"
    local dir
    local candidate
    local plist
    local -a search_dirs=(
        "${HOME}/Library/Developer/Xcode/UserData/Provisioning Profiles"
        "${HOME}/Library/MobileDevice/Provisioning Profiles"
        "/Library/MobileDevice/Provisioning Profiles"
    )
    for dir in "${search_dirs[@]}"; do
        [[ -d "${dir}" ]] || continue
        while IFS= read -r candidate; do
            plist="$(mktemp)"
            if decode_ios_provisioning_profile "${candidate}" "${plist}" >/dev/null 2>&1 &&
                profile_matches_bundle "${plist}" "${bundle_id}" &&
                profile_is_unexpired "${plist}"; then
                rm -f "${plist}"
                printf '%s\n' "${candidate}"
                return 0
            fi
            rm -f "${plist}"
        done < <(find "${dir}" -maxdepth 1 -type f -name '*.mobileprovision' -print 2>/dev/null | sort -r)
    done
    return 1
}

profile_matches_bundle() {
    local plist="$1"
    local bundle_id="$2"
    local appid
    local allowed
    appid="$(plutil -extract Entitlements.application-identifier raw -o - "${plist}" 2>/dev/null || true)"
    [[ -n "${appid}" ]] || return 1
    allowed="${appid#*.}"
    if [[ "${allowed}" == *'*' ]]; then
        [[ "${bundle_id}" == "${allowed%\*}"* ]]
    else
        [[ "${bundle_id}" == "${allowed}" ]]
    fi
}

profile_is_unexpired() {
    local plist="$1"
    local expiration
    expiration="$(plutil -extract ExpirationDate raw -o - "${plist}" 2>/dev/null || true)"
    [[ -n "${expiration}" ]] || return 1
    [[ "${expiration}" > "$(date -u +%Y-%m-%dT%H:%M:%SZ)" ]]
}

verify_device() {
    : "${CANGHUI_IOS_DEVICE:?set CANGHUI_IOS_DEVICE to a CoreDevice identifier, UDID or name}"
    : "${CANGHUI_IOS_BUNDLE_ID:?set CANGHUI_IOS_BUNDLE_ID to the signed application identifier}"
    : "${CANGHUI_IOS_CODESIGN_IDENTITY:?set CANGHUI_IOS_CODESIGN_IDENTITY to an Apple Development identity}"
    local profile_dir="${OUTPUT_ROOT}/device-profile"
    local profile_plist="${profile_dir}/profile.plist"
    local entitlements="${profile_dir}/entitlements.plist"
    local application_identifier
    local allowed_bundle
    local expiration
    mkdir -p "${profile_dir}"
    if [[ -z "${CANGHUI_IOS_PROVISIONING_PROFILE:-}" ]]; then
        local discovered
        if discovered="$(find_valid_provisioning_profile "${CANGHUI_IOS_BUNDLE_ID}")"; then
            CANGHUI_IOS_PROVISIONING_PROFILE="${discovered}"
            printf 'Discovered provisioning profile: %s\n' "${CANGHUI_IOS_PROVISIONING_PROFILE}"
        else
            printf 'No valid provisioning profile found for %s.\n' \
                "${CANGHUI_IOS_BUNDLE_ID}" >&2
            exit 1
        fi
    fi
    decode_ios_provisioning_profile "${CANGHUI_IOS_PROVISIONING_PROFILE}" "${profile_plist}"
    expiration="$(plutil -extract ExpirationDate raw -o - "${profile_plist}")"
    if [[ "${expiration}" < "$(date -u +%Y-%m-%dT%H:%M:%SZ)" ]]; then
        printf 'Provisioning profile expired at %s.\n' "${expiration}" >&2
        exit 1
    fi
    plutil -extract Entitlements xml1 -o "${entitlements}" "${profile_plist}"
    plutil -remove keychain-access-groups "${entitlements}" >/dev/null 2>&1 || true
    application_identifier="$(plutil -extract Entitlements.application-identifier raw -o - "${profile_plist}")"
    allowed_bundle="${application_identifier#*.}"
    if [[ "${allowed_bundle}" != *'*' && "${CANGHUI_IOS_BUNDLE_ID}" != "${allowed_bundle}" ]]; then
        printf 'Bundle id %s does not match provisioning profile %s.\n' \
            "${CANGHUI_IOS_BUNDLE_ID}" "${allowed_bundle}" >&2
        exit 1
    fi
    local target="aarch64-apple-ios"
    build_module "${target}"
    local repo
    repo="$(repository_dir "${target}")"
    compile_app device iphoneos "${repo}" "${CANGHUI_IOS_BUNDLE_ID}"
    cp "${CANGHUI_IOS_PROVISIONING_PROFILE}" "${APP_DIR}/embedded.mobileprovision"
    codesign --force --sign "${CANGHUI_IOS_CODESIGN_IDENTITY}" \
        --entitlements "${entitlements}" --generate-entitlement-der \
        --timestamp=none "${APP_DIR}"
    codesign --verify --deep --strict "${APP_DIR}"
    xcrun devicectl device install app --device "${CANGHUI_IOS_DEVICE}" "${APP_DIR}"
    : > "${LOG_FILE}"
    xcrun devicectl device process launch --device "${CANGHUI_IOS_DEVICE}" \
        --terminate-existing --console --timeout 25 "${CANGHUI_IOS_BUNDLE_ID}" \
        >"${LOG_FILE}" 2>&1 &
    wait_for_result "${LOG_FILE}" "$!"
}

case "${MODE}" in
    simulator) verify_simulator ;;
    device) verify_device ;;
    *)
        printf 'usage: %s [simulator|device] [output-dir]\n' "$0" >&2
        exit 2
        ;;
esac
