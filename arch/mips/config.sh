# $Id$
#
# Arch-specific options that normally shouldn't be changed.
#
KERNEL_MAKE_DIRECTIVE="vmlinux"
KERNEL_MAKE_DIRECTIVE_2=""
KERNEL_BINARY="./vmlinux"

# Initrd/Initramfs Options
USECOLOR="yes"
NOINITRDMODULES="yes"
BUSYBOX=1
DMRAID=0
DISKLABEL=0

# genkernel on mips is only used for LiveCDs && netboots.  Catalyst
# will know where to get the kernels at.
CMD_INSTALL=0

#
# Arch-specific defaults that can be overridden in the config file or on the
# command line.
#
DEFAULT_COMPRESS_INITRD=yes
DEFAULT_COMPRESS_INITRD_TYPE=best
DEFAULT_KERNEL_MAKE=make
DEFAULT_UTILS_MAKE=make
DEFAULT_UTILS_CC=gcc
DEFAULT_UTILS_AS=as
DEFAULT_UTILS_LD=ld

