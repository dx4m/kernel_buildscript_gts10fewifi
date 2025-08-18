#!/bin/bash

# SPDX-License-Identifier: GPL-3.0
#
# Kernel build script for Samsung Tab S10 FE

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
KERNELBUILD="${CURRENT_DIR}/kernelbuild"

TOOLS="${KERNELBUILD}/tools"
PREBUILTS="${KERNELBUILD}/prebuilts"
EXTERNAL="${KERNELBUILD}/external"
BUILD="${KERNELBUILD}/build"

KERNEL_DIR="${KERNELBUILD}/common"
OUTPUT_DIR="${CURRENT_DIR}/out"

DISABLE_SAMSUNG_PROTECTION=true
ENABLE_KERNELSU=true
MENUCONFIG=false
PRINTHELP=false
CLEAN=false

VERSION="android15-8-abX520XXU1AYC5"

if [ ! -d $PREBUILTS ]; then
	echo "[❌] Missing prebuilts"
	exit 1
fi

if [ ! -d $KERNEL_DIR ]; then
	echo "[❌] Missing kernel"
	exit 1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --disable-samsung-protection)
            DISABLE_SAMSUNG_PROTECTION=true
            shift
            ;;
        --enable-kernelsu)
            ENABLE_KERNELSU=true
            shift
            ;;
		menuconfig)
            MENUCONFIG=true
            shift
            ;;
		clean)
            CLEAN=true
            shift
            ;;
		--help)
            PRINTHELP=true
            shift
            ;;
        *)
            OTHER_ARGS+=("$1")
            shift
            ;;
    esac
done

if [ "$PRINTHELP" = true ]; then
	echo "build_kernel.sh [OPTIONS]"
	echo "OPTIONS:"
	echo "	--disable-samsung-protection (DEFAULT)"
	echo "	--enable-kernelsu (Enables KernelSU/SukiSU Ultra in config. Follow KernelSU building guide)"
	echo "	--help (Prints this message)"
	echo "	menuconfig (opens menuconfig)"
	exit 1
fi

if [ "$CLEAN" = true ]; then
	if [ ! -d $OUTPUT_DIR ]; then
		echo "[✅] Already clean."
		exit 1
	fi
	
	rm -rf $OUTPUT_DIR
	echo "[✅] Cleaned output."
	exit 1
fi

export PATH="${PREBUILTS}/build-tools/linux-x86/bin:${PATH}"
export PATH="${PREBUILTS}/build-tools/path/linux-x86:${PATH}"
export PATH="${PREBUILTS}/clang/host/linux-x86/clang-r510928/bin:${PATH}"
export PATH="${PREBUILTS}/kernel-build-tools/linux-x86/bin:${PATH}"

LLD_COMPILER_RT="-fuse-ld=lld --rtlib=compiler-rt"
SYSROOT_FLAGS="--sysroot=${PREBUILTS}/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/sysroot"

CFLAGS="-I${PREBUILTS}/kernel-build-tools/linux-x86/include "
LDFLAGS="-L${PREBUILTS}/kernel-build-tools/linux-x86/lib64 ${LLD_COMPILER_RT}"

export LD_LIBRARY_PATH="${PREBUILTS}/kernel-build-tools/linux-x86/lib64"
export HOSTCFLAGS="${SYSROOT_FLAGS} ${CFLAGS}"
export HOSTLDFLAGS="${SYSROOT_FLAGS} ${LDFLAGS}"

TARGET_DEFCONFIG="${1:-gts10fewifi_defconfig}"
ARGS="CC=clang ARCH=arm64 LLVM=1 LLVM_IAS=1"

if [ "$MENUCONFIG" = true ]; then
	make -j"$(nproc)" \
     -C "${KERNEL_DIR}" \
     O="${OUTPUT_DIR}" \
     ${ARGS} \
     "${TARGET_DEFCONFIG}" menuconfig
else
	make -j"$(nproc)" \
     -C "${KERNEL_DIR}" \
     O="${OUTPUT_DIR}" \
     ${ARGS} \
     "${TARGET_DEFCONFIG}"
fi

CONFIG_FILE="${OUTPUT_DIR}/.config"
if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "[❌] .config not found at ${CONFIG_FILE}"
  exit 1
fi

if [ "$ENABLE_KERNELSU" = true ]; then
	if [ ! -d $KERNEL_DIR/KernelSU ]; then
		echo "[❗] Can't enable KernelSU in config. KernelSU doesn't exist."
		ENABLE_KERNELSU=false
	else
		DISABLE_SAMSUNG_PROTECTION=true
		"${KERNEL_DIR}/scripts/config" --file "${CONFIG_FILE}" \
			-e CONFIG_KSU -d CONFIG_KSU_KPROBES_HOOK
	fi
fi

# Disable Samsung Protection
if [ "$DISABLE_SAMSUNG_PROTECTION" = true ]; then
	
	"${KERNEL_DIR}/scripts/config" --file "${CONFIG_FILE}" \
		-d UH -d RKP -d KDP -d SECURITY_DEFEX -d INTEGRITY -d FIVE \
		-d TRIM_UNUSED_KSYMS -d PROCA -d PROCA_GKI_10 -d PROCA_S_OS \
		-d PROCA_CERTIFICATES_XATTR -d PROCA_CERT_ENG -d PROCA_CERT_USER \
		-d GAF -d GAF_V6 -d FIVE_CERT_USER -d FIVE_DEFAULT_HASH \
		-e CONFIG_TMPFS_XATTR -e CONFIG_TMPFS_POSIX_ACL

	
	"${KERNEL_DIR}/scripts/config" --file "${CONFIG_FILE}" \
		-e CONFIG_TMPFS_XATTR -e CONFIG_TMPFS_POSIX_ACL
fi

# Change LOCALVERSION
"${KERNEL_DIR}/scripts/config" --file "${CONFIG_FILE}" \
  --set-str CONFIG_LOCALVERSION "-$VERSION-4k" -d CONFIG_LOCALVERSION_AUTO
  
# Fix Kernel Version to remove +
sed -i 's/echo "+"$/echo ""/' $KERNEL_DIR/scripts/setlocalversion

# Compile
make -j"$(nproc)" \
     -C "${KERNEL_DIR}" \
     O="${OUTPUT_DIR}" \
     ${ARGS}


# Restore fix from earlier
sed -i 's/echo ""$/echo "+"/' $KERNEL_DIR/scripts/setlocalversion

if [ -e $OUTPUT_DIR/arch/arm64/boot/Image ]; then
	echo "[✅] Kernel build finished."
	python3 $TOOLS/mkbootimg/mkbootimg.py --header_version 4 --kernel $OUTPUT_DIR/arch/arm64/boot/Image --cmdline '' --out $CURRENT_DIR/boot.img
	echo "[✅] Boot image generated at ${CURRENT_DIR}/boot.img"
	tar -cf $CURRENT_DIR/boot.img.tar boot.img
	echo "[✅] Odin flashable image at ${CURRENT_DIR}/boot.img.tar"
else
	echo "[❌] Kernel build failed."
fi
