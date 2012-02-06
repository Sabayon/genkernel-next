# $Id$
#
# Arch-specific options that normally shouldn't be changed.
#
KERNEL_MAKE_DIRECTIVE="vmlinux"
KERNEL_MAKE_DIRECTIVE_2="image"
KERNEL_BINARY="arch/sparc64/boot/image arch/sparc/boot/image"

USECOLOR="no"

#
# Arch-specific defaults that can be overridden in the config file or on the
# command line.
#
DEFAULT_COMPRESS_INITRD=yes
DEFAULT_COMPRESS_INITRD_TYPE=best

DEFAULT_MAKEOPTS="-j2"

DEFAULT_KERNEL_MAKE=make
DEFAULT_UTILS_MAKE=make

DEFAULT_KERNEL_CC=sparc64-linux-gcc
#DEFAULT_KERNEL_AS=as
#DEFAULT_KERNEL_LD=ld

DEFAULT_UTILS_CC=gcc
DEFAULT_UTILS_AS=as
DEFAULT_UTILS_LD=ld
