#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=lavender
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

function blob_fixup() {
    case "${1}" in
        system_ext/etc/init/dpmd.rc)
            sed -i "s|/system/product/bin/|/system/system_ext/bin/|g" "${2}"
            ;;
        system_ext/etc/permissions/com.qti.dpmframework.xml | system_ext/etc/permissions/dpmapi.xml )
            sed -i "s|/system/product/framework/|/system/system_ext/framework/|g" "${2}"
            ;;
        system_ext/etc/permissions/qcrilhook.xml)
            sed -i 's|/product/framework/qcrilhook.jar|/system_ext/framework/qcrilhook.jar|g' "${2}"
            ;;
        system_ext/lib64/libdpmframework.so)
            for LIBSHIM_DPMFRAMEWORK in $(grep -L "libshim_dpmframework.so" "${2}"); do
                "${PATCHELF}" --add-needed "libshim_dpmframework.so" "$LIBSHIM_DPMFRAMEWORK"
            done
            ;;
        vendor/bin/mlipayd@1.1)
           "${PATCHELF}" --remove-needed vendor.xiaomi.hardware.mtdservice@1.0.so "${2}"
            ;;
        vendor/lib64/libmlipay.so | vendor/lib64/libmlipay@1.1.so)
            "${PATCHELF}" --remove-needed vendor.xiaomi.hardware.mtdservice@1.0.so "${2}"
            sed -i "s|/system/etc/firmware|/vendor/firmware\x0\x0\x0\x0|g" "${2}"
            ;;
        vendor/lib64/vendor.xiaomi.hardware.mlipay@1.0.so | vendor/lib64/vendor.xiaomi.hardware.mlipay@1.1.so)
            "${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${2}"
            ;;
        vendor/lib/vendor.qti.hardware.fingerprint@1.0.so | vendor/lib64/vendor.qti.hardware.fingerprint@1.0.so)
            "${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${2}"
            ;;
        vendor/lib/libFaceGrade.so | vendor/lib/libXMFD_AgeGender.so | vendor/lib/lib_lowlight.so | vendor/lib/libarcsoft_beautyshot.so | vendor/lib/libchromaflash.so | vendor/lib/libdualcameraddm.so | vendor/lib/libmmcamera_hdr_gb_lib.so | vendor/lib/liboptizoom.so | vendor/lib/libseemore.so | vendor/lib/libtrueportrait.so | vendor/lib/libts_detected_face_hal.so | vendor/lib/libts_face_beautify_hal.so | vendor/lib/libubifocus.so | vendor/lib/libvideobokeh.so | vendor/lib64/libchromaflash.so | vendor/lib64/libdualcameraddm.so | vendor/lib64/liboptizoom.so | vendor/lib64/libseemore.so | vendor/lib64/libts_detected_face_hal.so | vendor/lib64/libubifocus.so | vendor/lib64/libvideobokeh.so)
            "${PATCHELF}" --replace-needed "libstdc++.so" "libstdc++_vendor.so" "${2}"
            ;;
    esac
}

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
