# NOTE:
# - This file (software.sh) is sourced by genkernel.
#   Rather than changing this very file, please override specific versions/variables
#   somewhere in /etc/genkernel.conf .
#
# - Any VERSION_* magic strings below will be filled (or already have been)
#   with actual version strings by the genkernel ebuild.
#
# - This file should not override previously defined variables, as their values may
#   originate from user changes to /etc/genkernel.conf .

BUSYBOX_VER="1.20.2"
BUSYBOX_SRCTAR="${BUSYBOX_SRCTAR:-${DISTDIR}/busybox-${BUSYBOX_VER}.tar.bz2}"
BUSYBOX_DIR="${BUSYBOX_DIR:-busybox-${BUSYBOX_VER}}"
BUSYBOX_BINCACHE="${BUSYBOX_BINCACHE:-%%CACHE%%/busybox-${BUSYBOX_VER}-%%ARCH%%.tar.bz2}"
