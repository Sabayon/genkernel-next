#!/bin/bash
# x86_64/config.sh

KERNEL_MAKE="bzImage"
KERNEL_MAKE_2=""
KERNEL_BINARY="arch/x86_64/boot/bzImage"

USE_DIETLIBC=1

MAKE=make

KERNEL_CC=gcc
KERNEL_AS=as
KERNEL_LD=ld

UTILS_CC=gcc
UTILS_AS=as
UTILS_LD=ld

COMPRESS_INITRD=yes

