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

BUSYBOX_VER="${BUSYBOX_VER:-VERSION_BUSYBOX}"
BUSYBOX_SRCTAR="${BUSYBOX_SRCTAR:-${DISTDIR}/busybox-${BUSYBOX_VER}.tar.bz2}"
BUSYBOX_DIR="${BUSYBOX_DIR:-busybox-${BUSYBOX_VER}}"
BUSYBOX_BINCACHE="${BUSYBOX_BINCACHE:-%%CACHE%%/busybox-${BUSYBOX_VER}-%%ARCH%%.tar.bz2}"

MDADM_VER="${MDADM_VER:-VERSION_MDADM}"
MDADM_DIR="${MDADM_DIR:-mdadm-${MDADM_VER}}"
MDADM_SRCTAR="${MDADM_SRCTAR:-${DISTDIR}/mdadm-${MDADM_VER}.tar.bz2}"
MDADM_BINCACHE="${MDADM_BINCACHE:-%%CACHE%%/mdadm-${MDADM_VER}-%%ARCH%%.tar.bz2}"

ISCSI_VER="${ISCSI_VER:-VERSION_ISCSI}"
ISCSI_DIR="${ISCSI_DIR:-open-iscsi-${ISCSI_VER}}"
ISCSI_SRCTAR="${ISCSI_SRCTAR:-${DISTDIR}/open-iscsi-${ISCSI_VER}.tar.gz}"
ISCSI_BINCACHE="${ISCSI_BINCACHE:-%%CACHE%%/iscsi-${ISCSI_VER}-%%ARCH%%.bz2}"

FUSE_VER="${FUSE_VER:-VERSION_FUSE}"
FUSE_DIR="${FUSE_DIR:-fuse-${FUSE_VER}}"
FUSE_SRCTAR="${FUSE_SRCTAR:-${DISTDIR}/fuse-${FUSE_VER}.tar.gz}"
FUSE_BINCACHE="${FUSE_BINCACHE:-%%CACHE%%/fuse-${FUSE_VER}-%%ARCH%%.tar.bz2}"

UNIONFS_FUSE_VER="${UNIONFS_FUSE_VER:-VERSION_UNIONFS_FUSE}"
UNIONFS_FUSE_DIR="${UNIONFS_FUSE_DIR:-unionfs-fuse-${UNIONFS_FUSE_VER}}"
UNIONFS_FUSE_SRCTAR="${UNIONFS_FUSE_SRCTAR:-${DISTDIR}/unionfs-fuse-${UNIONFS_FUSE_VER}.tar.bz2}"
UNIONFS_FUSE_BINCACHE="${UNIONFS_FUSE_BINCACHE:-%%CACHE%%/unionfs-fuse-${UNIONFS_FUSE_VER}-%%ARCH%%.bz2}"

GPG_VER="${GPG_VER:-VERSION_GPG}"
GPG_DIR="${GPG_DIR:-gnupg-${GPG_VER}}"
GPG_SRCTAR="${GPG_SRCTAR:-${DISTDIR}/gnupg-${GPG_VER}.tar.bz2}"
GPG_BINCACHE="${GPG_BINCACHE:-%%CACHE%%/gnupg-${GPG_VER}-%%ARCH%%.bz2}"
