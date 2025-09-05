#!/bin/bash

# SPDX-License-Identifier: GPL-3.0
#
# Kernel build script for Samsung Tab S10 FE

KERNEL_AOSP="kernel-aosp"
KERNELBUILD="kernelbuild"

TOOLS="${KERNELBUILD}/tools"
PREBUILTS="${KERNELBUILD}/prebuilts"
EXTERNAL="${KERNELBUILD}/external"
BUILD="${KERNELBUILD}/build"

KERNEL_DIR="${KERNELBUILD}/common"
DEFCONFIG_DIR="${KERNEL_DIR}/arch/arm64/configs/gts10fewifi_defconfig"
CURRENT_DIR="$(pwd)"

function getAOSPKernel() {
	echo "[💠] Getting AOSP Kernel because of the buildchain"
	mkdir $KERNEL_AOSP && cd $KERNEL_AOSP
	repo init -u https://android.googlesource.com/kernel/manifest -b common-android15-6.6
	repo sync
	cd ..
	echo "[✅] Done."
}

function getSamsungKernel() {
	echo "[💠] Getting Samsung kernel from github"
	mkdir $KERNELBUILD && cd $KERNELBUILD
	git clone https://github.com/dx4m/android_kernel_gts10fewifi -b android15-6.6 common
	cd ..
	echo "[✅] Done."
}

function movePrebuilts() {
	echo "[💠] Moving buildchain from AOSP to ${KERNELBUILD} folder"
	mv $KERNEL_AOSP/tools $TOOLS
	mv $KERNEL_AOSP/prebuilts $PREBUILTS
	mv $KERNEL_AOSP/external $EXTERNAL
	mv $KERNEL_AOSP/build $BUILD
	echo "[✅] Done."
}

function copyDefconfig() {
	cp $CURRENT_DIR/defconfig $DEFCONFIG_DIR
	cp $CURRENT_DIR/abi_symbollist.raw $KERNEL_DIR
	chmod +x $DEFCONFIG_DIR
}

function removeAOSPKernel() {
	echo "[💠] Remove AOSP"

	rm -rf $KERNEL_AOSP

	echo "[✅] Done."
}


if [ ! -d $KERNELBUILD ]; then
	getSamsungKernel
	copyDefconfig
fi

if [ ! -d $PREBUILTS ]; then
	if [ ! -d $KERNEL_AOSP ]; then
		getAOSPKernel
	fi

	movePrebuilts
	removeAOSPKernel
fi
