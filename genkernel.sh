#!/bin/bash
# Genkernel v3.0

GK_V="3.0"
TEMP="/tmp"

small_die() {
  echo $1
  exit 1
}

source /etc/genkernel.conf || small_die "could not read /etc/genkernel.conf"
source ${GK_BIN}/gen_funcs.sh || small_die "could not read ${GK_BIN}/gen_funcs.sh"
clear_log
source ${GK_BIN}/gen_cmdline.sh || gen_die "could not read ${GK_BIN}/gen_cmdline.sh"
source ${GK_BIN}/gen_arch.sh || gen_die "could not read ${GK_BIN}/gen_arch.sh"
source ${GK_BIN}/gen_determineargs.sh || gen_die "could not read ${GK_BIN}/gen_determineargs.sh"
source ${GK_BIN}/gen_compile.sh || gen_die "could not read ${GK_BIN}/gen_compile.sh"
source ${GK_BIN}/gen_configkernel.sh || gen_die "could not read ${GK_BIN}/gen_configkernel.sh"
source ${GK_BIN}/gen_initrd.sh || gen_die "could not read ${GK_BIN}/gen_initrd.sh"
source ${GK_BIN}/gen_moddeps.sh || gen_die "could not read ${GK_BIN}/gen_moddeps.sh"

# Parse all command line options, and load into memory
parse_cmdline $*

print_info 1 "GenKernel v${GK_V}" 1 0

# Set ${ARCH}
get_official_arch

# Read arch-specific config
source ${ARCH_CONFIG} || gen_die "could not read ${ARCH_CONFIG}"
source ${GK_SHARE}/${ARCH}/modules_load || gen_die "could not read ${GK_SHARE}/${ARCH}/modules_load"

# Based on genkernel.conf, arch-specific configs, and commandline options,
# get the real args for use.
determine_real_args

print_info 1 "ARCH: ${ARCH}"

# Configure kernel
config_kernel

# Make deps
compile_dep

# Compile modules
compile_modules

# Compile kernel
compile_kernel

# Compile dietlibc
if [ "${USE_DIETLIBC}" = "1" ]
then
	compile_dietlibc
fi

# Compile Busybox
compile_busybox

if [ "${PAT}" -gt "4" ]
then
	# Compile module-init-tools
	compile_module_init_tools
else
	compile_modutils
fi

compile_devfsd

# Create initrd
create_initrd

print_info 1 "DONE"
