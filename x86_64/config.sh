#!/bin/bash
# x86_64/config.sh

KERNEL_MAKE="bzImage"
KERNEL_BINARY="arch/x86_64/boot/bzImage"

# Busybox 1.00-pre3 won't build with dietlibc, when it does we
# can turn this flag on
USE_DIETLIBC=0

KERNEL_CC=gcc
KERNEL_AS=as
KERNEL_LD=ld

UTILS_CC=gcc
UTILS_AS=as
UTILS_LD=ld

COMPRESS_INITRD=yes

