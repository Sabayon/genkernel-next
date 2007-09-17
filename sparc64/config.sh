#!/bin/bash

KERNEL_MAKE_DIRECTIVE="vmlinux"
KERNEL_MAKE_DIRECTIVE_2="image"
KERNEL_BINARY="arch/sparc64/boot/image"

[ -z "${MAKEOPTS}" ] && MAKEOPTS="-j2"

KERNEL_MAKE=make
UTILS_MAKE=make

KERNEL_CC=sparc64-linux-gcc
#KERNEL_AS=as
#KERNEL_LD=ld

UTILS_CC=gcc
UTILS_AS=as
UTILS_LD=ld

COMPRESS_INITRD=yes
USECOLOR="no"
