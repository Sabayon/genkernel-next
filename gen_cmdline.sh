#!/bin/bash
# $Id$

longusage() {
  echo "Gentoo Linux Genkernel ${GK_V}"
  echo
  echo "Usage: "
  echo "  genkernel [options] action"
  echo
  echo "Available Actions: "
  echo "  all               Build all steps"
  echo "  bzImage           Build only the kernel"
  echo "  initramfs         Build only the ramdisk/initramfs"
  echo "  kernel            Build only the kernel and modules"
  echo "  ramdisk           Build only the ramdisk/initramfs"
  echo
  echo "Available Options: "
  echo "  Configuration settings"
  echo "    --config=<file> genkernel configuration file to use"
  echo "  Debug settings"
  echo "    --loglevel=<0-5>    Debug Verbosity Level"
  echo "    --logfile=<outfile> Output file for debug info"
  echo "    --color         Output debug in color"
  echo "    --no-color      Do not output debug in color"
  echo "  Kernel Configuration settings"
  echo "    --menuconfig        Run menuconfig after oldconfig"
  echo "    --no-menuconfig     Do not run menuconfig after oldconfig"
  echo "    --nconfig       Run nconfig after oldconfig"
  echo "    --no-nconfig        Do not run nconfig after oldconfig"
  echo "    --gconfig           Run gconfig after oldconfig"
  echo "    --no-gconfig        Don't run gconfig after oldconfig"
  echo "    --xconfig           Run xconfig after oldconfig"
  echo "    --no-xconfig        Don't run xconfig after oldconfig"
  echo "    --save-config       Save the configuration to /etc/kernels"
  echo "    --no-save-config    Don't save the configuration to /etc/kernels"
  echo "    --virtio            Include VirtIO kernel code"
  echo "  Kernel Compile settings"
  echo "    --oldconfig     Implies --no-clean and runs a 'make oldconfig'"
  echo "    --clean         Run make clean before compilation"
  echo "    --no-clean      Do not run make clean before compilation"
  echo "    --mrproper      Run make mrproper before compilation"
  echo "    --no-mrproper   Do not run make mrproper before compilation"
  echo "    --splash        Install framebuffer splash support into initramfs"
  echo "    --no-splash     Do not install framebuffer splash"
  echo "    --plymouth      Enable plymouth support (forces --udev)"
  echo "    --no-plymouth       Do not enable plymouth support"
  echo "    --install       Install the kernel after building"
  echo "    --no-install        Do not install the kernel after building"
  echo "    --symlink       Manage symlinks in /boot for installed images"
  echo "    --no-symlink        Do not manage symlinks"
  echo "    --ramdisk-modules   Copy required modules to the ramdisk"
  echo "    --no-ramdisk-modules    Don't copy any modules to the ramdisk"
  echo "    --all-ramdisk-modules   Copy all kernel modules to the ramdisk"
  echo "    --callback=<...>    Run the specified arguments after the"
  echo "                kernel and modules have been compiled"
  echo "    --static        Build a static (monolithic kernel)."
  echo "    --no-static     Do not build a static (monolithic kernel)."
  echo "  Kernel settings"
  echo "    --kerneldir=<dir>   Location of the kernel sources"
  echo "    --kernel-config=<file>  Kernel configuration file to use for compilation"
  echo "    --module-prefix=<dir>   Prefix to kernel module destination, modules"
  echo "                will be installed in <prefix>/lib/modules"
  echo "  Low-Level Compile settings"
  echo "    --kernel-cc=<compiler>  Compiler to use for kernel (e.g. distcc)"
  echo "    --kernel-as=<assembler> Assembler to use for kernel"
  echo "    --kernel-ld=<linker>    Linker to use for kernel"
  echo "    --kernel-make=<makeprg> GNU Make to use for kernel"
  echo "    --kernel-target=<t> Override default make target (bzImage)"
  echo "    --kernel-binary=<path>  Override default kernel binary path (arch/foo/boot/bar)"
  echo "    --kernel-outputdir=<path> Save output files outside the source tree."

  echo "    --utils-cc=<compiler>   Compiler to use for utilities"
  echo "    --utils-as=<assembler>  Assembler to use for utils"
  echo "    --utils-ld=<linker> Linker to use for utils"
  echo "    --utils-make=<makeprog> GNU Make to use for utils"
  echo "    --utils-arch=<arch>     Force to arch for utils only instead of"
  echo "                autodetect."
  echo "    --makeopts=<makeopts>   Make options such as -j2, etc..."
  echo "    --mountboot     Mount BOOTDIR automatically if mountable"
  echo "    --no-mountboot      Don't mount BOOTDIR automatically"  
  echo "    --bootdir=<dir>     Set the location of the boot-directory, default is /boot"
  echo "    --modprobedir=<dir> Set the location of the modprobe.d-directory, default is /etc/modprobe.d"
  echo "  Initialization"
  echo "    --splash=<theme>    Enable framebuffer splash using <theme>"
  echo "    --splash-res=<res>  Select splash theme resolutions to install"
  echo "    --splash=<theme>    Enable framebuffer splash using <theme>"
  echo "    --splash-res=<res>  Select splash theme resolutions to install"
  echo "    --plymouth-theme=<theme>    Embed the given plymouth theme"
  echo "    --do-keymap-auto    Forces keymap selection at boot"
  echo "    --keymap        Enables keymap selection support"
  echo "    --no-keymap     Disables keymap selection support"
  echo "    --udev          Include udev and use it instead of mdev"
  echo "    --no-udev       Exclude udev and use it instead of mdev"
  echo "    --lvm           Include LVM support"
  echo "    --no-lvm        Exclude LVM support"
  echo "    --mdadm         Include MDADM/MDMON support"
  echo "    --no-mdadm      Exclude MDADM/MDMON support"
  echo "    --mdadm-config=<file>   Use file as mdadm.conf in initramfs"
  echo "    --dmraid        Include DMRAID support"
  echo "    --no-dmraid     Exclude DMRAID support"
  echo "    --e2fsprogs     Include e2fsprogs"
  echo "    --no-e2fsprogs      Exclude e2fsprogs"
  echo "    --zfs           Include ZFS support"
  echo "    --no-zfs        Exclude ZFS support"
  echo "    --btrfs         Include BTRFS support"
  echo "    --no-btrfs      Exclude BTRFS support"
  echo "    --multipath     Include Multipath support"
  echo "    --no-multipath  Exclude Multipath support"
  echo "    --iscsi         Include iSCSI support"
  echo "    --no-iscsi      Exclude iSCSI support"
  echo "    --bootloader=grub   Add new kernel to GRUB configuration"
  echo "    --linuxrc=<file>    Specifies a user created linuxrc"
  echo "    --busybox-config=<file> Specifies a user created busybox config"
  echo "    --genzimage     Make and install kernelz image (PowerPC)"
  echo "    --luks          Include LUKS support"
  echo "                --> 'emerge cryptsetup-luks' with USE=-dynamic"
  echo "    --no-luks       Exclude LUKS support"
  echo "    --gpg           Include GPG-armored LUKS key support"
  echo "    --no-gpg        Exclude GPG-armored LUKS key support"
  echo "    --busybox       Include busybox"
  echo "    --no-busybox    Exclude busybox"
  echo "    --netboot       Create a self-contained env in the initramfs"
  echo "    --no-netboot    Exclude --netboot env"
  echo "    --real-root=<foo>   Specify a default for real_root="
  echo "  Internals"
  echo "    --arch-override=<arch>  Force to arch instead of autodetect"
  echo "    --cachedir=<dir>    Override the default cache location"
  echo "    --tempdir=<dir>     Location of Genkernel's temporary directory"
  echo "    --postclear         Clear all tmp files and caches after genkernel has run"
  echo "    --no-postclear      Do not clean up after genkernel has run"
  echo "  Output Settings"
  echo "    --kernname=<...>    Tag the kernel and ramdisk with a name:"
  echo "                If not defined the option defaults to"
  echo "                'genkernel'"
  echo "    --appendname=<...>    Append a text to the kernel and ramdisk's name:"
  echo "                If not defined the appendname is empty"
  echo "    --minkernpackage=<tbz2> File to output a .tar.bz2'd kernel and ramdisk:"
  echo "                No modules outside of the ramdisk will be"
  echo "                included..."
  echo "    --modulespackage=<tbz2> File to output a .tar.bz2'd modules after the"
  echo "                callbacks have run"
  echo "    --kerncache=<tbz2>  File to output a .tar.bz2'd kernel contents"
  echo "                of /lib/modules/ and the kernel config"
  echo "                NOTE: This is created before the callbacks"
  echo "                are run!"
  echo "    --no-kernel-sources This option is only valid if kerncache is"
  echo "                defined. If there is a valid kerncache no checks"
  echo "                will be made against a kernel source tree"
  echo "    --initramfs-overlay=<dir>"
  echo "                Directory structure to include in the initramfs,"
  echo "                only available on 2.6 kernels"
  echo "    --firmware"
  echo "                Enable copying of firmware into initramfs"
  echo "    --firmware-dir=<dir>"
  echo "                Specify directory to copy firmware from (defaults"
  echo "                to /lib/firmware)"
  echo "    --firmware-files=<files>"
  echo "                Specifies specific firmware files to copy. This"
  echo "                overrides --firmware-dir. For multiple files,"
  echo "                separate the filenames with a comma"
  echo "    --integrated-initramfs, --no-integrated-initramfs"
  echo "                Include/exclude the generated initramfs in the kernel"
  echo "                instead of keeping it as a separate file"
  echo "    --compress-initramfs, --no-compress-initramfs,"
  echo "    --compress-initrd, --no-compress-initrd"
  echo "                Compress or do not compress the generated initramfs"
  echo "    --compress-initramfs-type=<arg>"
  echo "                Compression type for initramfs (best, xz, lzma, bzip2, gzip, lzop, lz4)"
}

usage() {
  echo "Gentoo Linux Genkernel ${GK_V}"
  echo
  echo "Usage: "
  echo "    genkernel [options] all"
  echo
  echo 'Some useful options:'
  echo '    --menuconfig        Run menuconfig after oldconfig'
  echo '    --nconfig       Run nconfig after oldconfig (requires ncurses)'
  echo '    --no-clean      Do not run make clean before compilation'
  echo '    --no-mrproper       Do not run make mrproper before compilation,'
  echo '                this is implied by --no-clean.'
  echo
  echo 'For a detailed list of supported options and flags; issue:'
  echo '    genkernel --help'
}

parse_optbool() {
    local opt=${1/--no-*/0} # false
    opt=${opt/--*/1} # true
    echo $opt
}

parse_cmdline() {
    case "$*" in
        --kernel-cc=*)
            CMD_KERNEL_CC=`parse_opt "$*"`
            print_info 2 "CMD_KERNEL_CC: ${CMD_KERNEL_CC}"
            ;;
        --kernel-ld=*)
            CMD_KERNEL_LD=`parse_opt "$*"`
            print_info 2 "CMD_KERNEL_LD: ${CMD_KERNEL_LD}"
            ;;
        --kernel-as=*)
            CMD_KERNEL_AS=`parse_opt "$*"`
            print_info 2 "CMD_KERNEL_AS: ${CMD_KERNEL_AS}"
            ;;
        --kernel-make=*)
            CMD_KERNEL_MAKE=`parse_opt "$*"`
            print_info 2 "CMD_KERNEL_MAKE: ${CMD_KERNEL_MAKE}"
            ;;
        --kernel-target=*)
            KERNEL_MAKE_DIRECTIVE_OVERRIDE=`parse_opt "$*"`
            print_info 2 "KERNEL_MAKE_DIRECTIVE_OVERRIDE: ${KERNEL_MAKE_DIRECTIVE_OVERRIDE}"
            ;;
        --kernel-binary=*)
            KERNEL_BINARY_OVERRIDE=`parse_opt "$*"`
            print_info 2 "KERNEL_BINARY_OVERRIDE: ${KERNEL_BINARY_OVERRIDE}"
            ;;
        --kernel-outputdir=*)
            CMD_KERNEL_OUTPUTDIR=`parse_opt "$*"`
            print_info 2 "CMD_KERNEL_OUTPUTDIR: ${CMD_KERNEL_OUTPUTDIR}"
            ;;
        --utils-cc=*)
            CMD_UTILS_CC=`parse_opt "$*"`
            print_info 2 "CMD_UTILS_CC: ${CMD_UTILS_CC}"
            ;;
        --utils-ld=*)
            CMD_UTILS_LD=`parse_opt "$*"`
            print_info 2 "CMD_UTILS_LD: ${CMD_UTILS_LD}"
            ;;
        --utils-as=*)
            CMD_UTILS_AS=`parse_opt "$*"`
            print_info 2 "CMD_UTILS_AS: ${CMD_UTILS_AS}"
            ;;
        --utils-make=*)
            CMD_UTILS_MAKE=`parse_opt "$*"`
            print_info 2 "CMD_UTILS_MAKE: ${CMD_UTILS_MAKE}"
            ;;
        --utils-arch=*)
            CMD_UTILS_ARCH=`parse_opt "$*"`
            print_info 2 "CMD_UTILS_ARCH: ${CMD_ARCHOVERRIDE}"
            ;;
        --makeopts=*)
            CMD_MAKEOPTS=`parse_opt "$*"`
            print_info 2 "CMD_MAKEOPTS: ${CMD_MAKEOPTS}"
            ;;
        --mountboot|--no-mountboot)
            CMD_MOUNTBOOT=`parse_optbool "$*"`
            print_info 2 "CMD_MOUNTBOOT: ${CMD_MOUNTBOOT}"
            ;;
        --bootdir=*)
            CMD_BOOTDIR=`parse_opt "$*"`
            print_info 2 "CMD_BOOTDIR: ${CMD_BOOTDIR}"
            ;;
        --modprobedir=*)
            CMD_MODPROBEDIR=`parse_opt "$*"`
            print_info 2 "CMD_MODPROBEDIR: ${CMD_MODPROBEDIR}"
            ;;
        --do-keymap-auto)
            CMD_DOKEYMAPAUTO=1
            CMD_KEYMAP=1
            print_info 2 "CMD_DOKEYMAPAUTO: ${CMD_DOKEYMAPAUTO}"
            ;;
        --keymap|--no-keymap)
            CMD_KEYMAP=`parse_optbool "$*"`
            print_info 2 "CMD_KEYMAP: ${CMD_KEYMAP}"
            ;;
        --udev|--no-udev)
            CMD_UDEV=`parse_optbool "$*"`
            print_info 2 "CMD_UDEV: ${CMD_UDEV}"
            ;;
        --lvm|--no-lvm)
            CMD_LVM=`parse_optbool "$*"`
            print_info 2 "CMD_LVM: ${CMD_LVM}"
            ;;
        --lvm2|--no-lvm2)
            CMD_LVM=`parse_optbool "$*"`
            print_info 2 "CMD_LVM: ${CMD_LVM}"
            echo
            print_warning 1 "Please use --lvm, as --lvm2 is deprecated."
            ;;
        --mdadm|--no-mdadm)
            CMD_MDADM=`parse_optbool "$*"`
            print_info 2 "CMD_MDADM: $CMD_MDADM"
            ;;
        --mdadm-config=*)
            CMD_MDADM_CONFIG=`parse_opt "$*"`
            print_info 2 "CMD_MDADM_CONFIG: $CMD_MDADM_CONFIG"
            ;;
        --busybox|--no-busybox)
            CMD_BUSYBOX=`parse_optbool "$*"`
            print_info 2 "CMD_BUSYBOX: ${CMD_BUSYBOX}"
            ;;
        --netboot|--no-netboot)
            CMD_NETBOOT=`parse_optbool "$*"`
            print_info 2 "CMD_NETBOOT: ${CMD_NETBOOT}"
            ;;
        --real-root=*)
            CMD_REAL_ROOT=`parse_opt "$*"`
            print_info 2 "CMD_REAL_ROOT: ${CMD_REAL_ROOT}"
            ;;
        --dmraid|--no-dmraid)
            CMD_DMRAID=`parse_optbool "$*"`
            if [ "$CMD_DMRAID" = "1" -a ! -e /usr/include/libdevmapper.h ]
            then
                echo 'Error: --dmraid requires LVM2 to be installed'
                echo '       on the host system; try "emerge lvm2".'
                exit 1
            fi
            print_info 2 "CMD_DMRAID: ${CMD_DMRAID}"
            ;;
        --e2fsprogs|--no-e2fsprogs)
            CMD_E2FSPROGS=`parse_optbool "$*"`
            print_info 2 "CMD_E2FSPROGS: ${CMD_E2FSPROGS}"
            ;;
        --zfs|--no-zfs)
            CMD_ZFS=`parse_optbool "$*"`
            print_info 2 "CMD_ZFS: ${CMD_ZFS}"
            ;;
        --btrfs|--no-btrfs)
            CMD_BTRFS=`parse_optbool "$*"`
            print_info 2 "CMD_BTRFS: ${CMD_BTRFS}"
            ;;
        --virtio)
            CMD_VIRTIO=`parse_optbool "$*"`
            print_info 2 "CMD_VIRTIO: ${CMD_VIRTIO}"
            ;;
        --multipath|--no-multipath)
            CMD_MULTIPATH=`parse_optbool "$*"`
            if [ "$CMD_MULTIPATH" = "1" -a ! -e /usr/include/libdevmapper.h ]
            then
                echo 'Error: --multipath requires LVM2 to be installed'
                echo '       on the host;system; try "emerge lvm2".'
                exit 1
            fi
            print_info 2 "CMD_MULTIPATH: ${CMD_MULTIPATH}"
            ;;
        --bootloader=*)
            CMD_BOOTLOADER=`parse_opt "$*"`
            print_info 2 "CMD_BOOTLOADER: ${CMD_BOOTLOADER}"
            ;;
        --iscsi|--no-iscsi)
            CMD_ISCSI=`parse_optbool "$*"`
            print_info 2 "CMD_ISCSI: ${CMD_ISCSI}"
            ;;
        --loglevel=*)
            CMD_LOGLEVEL=`parse_opt "$*"`
            LOGLEVEL="${CMD_LOGLEVEL}"
            print_info 2 "CMD_LOGLEVEL: ${CMD_LOGLEVEL}"
            ;;
        --menuconfig)
            TERM_LINES=`stty -a | head -n 1 | cut -d\  -f5 | cut -d\; -f1`
            TERM_COLUMNS=`stty -a | head -n 1 | cut -d\  -f7 | cut -d\; -f1`
            if [[ TERM_LINES -lt 19 || TERM_COLUMNS -lt 80 ]]
            then
                echo "Error: You need a terminal with at least 80 columns"
                echo "       and 19 lines for --menuconfig; try --no-menuconfig..."
                exit 1
            fi
            CMD_MENUCONFIG=1
            print_info 2 "CMD_MENUCONFIG: ${CMD_MENUCONFIG}"
            ;;
        --no-menuconfig)
            CMD_MENUCONFIG=0
            print_info 2 "CMD_MENUCONFIG: ${CMD_MENUCONFIG}"
            ;;
        --nconfig)
            CMD_NCONFIG=1
            print_info 2 "CMD_NCONFIG: ${CMD_NCONFIG}"
            ;;
        --no-nconfig)
            CMD_NCONFIG=0
            print_info 2 "CMD_NCONFIG: ${CMD_NCONFIG}"
            ;;
        --gconfig|--no-gconfig)
            CMD_GCONFIG=`parse_optbool "$*"`
            print_info 2 "CMD_GCONFIG: ${CMD_GCONFIG}"
            ;;
        --xconfig|--no-xconfig)
            CMD_XCONFIG=`parse_optbool "$*"`
            print_info 2 "CMD_XCONFIG: ${CMD_XCONFIG}"
            ;;
        --save-config|--no-save-config)
            CMD_SAVE_CONFIG=`parse_optbool "$*"`
            print_info 2 "CMD_SAVE_CONFIG: ${CMD_SAVE_CONFIG}"
            ;;
        --mrproper|--no-mrproper)
            CMD_MRPROPER=`parse_optbool "$*"`
            print_info 2 "CMD_MRPROPER: ${CMD_MRPROPER}"
            ;;
        --clean|--no-clean)
            CMD_CLEAN=`parse_optbool "$*"`
            print_info 2 "CMD_CLEAN: ${CMD_CLEAN}"
            ;;
        --oldconfig|--no-oldconfig)
            CMD_OLDCONFIG=`parse_optbool "$*"`
            [ "$CMD_OLDCONFIG" = "1" ] && CMD_CLEAN=0
            print_info 2 "CMD_CLEAN: ${CMD_CLEAN}"
            print_info 2 "CMD_OLDCONFIG: ${CMD_OLDCONFIG}"
            ;;
        --gensplash=*)
            CMD_SPLASH=1
            SPLASH_THEME=`parse_opt "$*"`
            print_info 2 "CMD_SPLASH: ${CMD_SPLASH}"
            print_info 2 "SPLASH_THEME: ${SPLASH_THEME}"
            echo
            print_warning 1 "Please use --splash, as --gensplash is deprecated."
            ;;
        --gensplash|--no-gensplash)
            CMD_SPLASH=`parse_optbool "$*"`
            SPLASH_THEME='default'
            print_info 2 "CMD_SPLASH: ${CMD_SPLASH}"
            echo
            print_warning 1 "Please use --splash, as --gensplash is deprecated."
            ;;
        --splash=*)
            CMD_SPLASH=1
            SPLASH_THEME=`parse_opt "$*"`
            print_info 2 "CMD_SPLASH: ${CMD_SPLASH}"
            print_info 2 "SPLASH_THEME: ${SPLASH_THEME}"
            ;;
        --splash|--no-splash)
            CMD_SPLASH=`parse_optbool "$*"`
            SPLASH_THEME='default'
            print_info 2 "CMD_SPLASH: ${CMD_SPLASH}"
            ;;
        --gensplash-res=*)
            SPLASH_RES=`parse_opt "$*"`
            print_info 2 "SPLASH_RES: ${SPLASH_RES}"
            echo
            print_warning 1 "Please use --splash-res, as --gensplash-res is deprecated."
            ;;
        --splash-res=*)
            SPLASH_RES=`parse_opt "$*"`
            print_info 2 "SPLASH_RES: ${SPLASH_RES}"
            ;;
        --plymouth)
            CMD_PLYMOUTH=1
            CMD_UDEV=1  # mdev is not really supported
            PLYMOUTH_THEME='text'
            print_info 2 "CMD_PLYMOUTH: ${CMD_PLYMOUTH}"
            ;;
        --plymouth-theme=*)
            CMD_PLYMOUTH=1
            PLYMOUTH_THEME=`parse_opt "$*"`
            print_info 2 "CMD_PLYMOUTH: ${CMD_PLYMOUTH}"
            print_info 2 "PLYMOUTH_THEME: ${PLYMOUTH_THEME}"
            ;;
        --install|--no-install)
            CMD_INSTALL=`parse_optbool "$*"`
            print_info 2 "CMD_INSTALL: ${CMD_INSTALL}"
            ;;
        --ramdisk-modules|--no-ramdisk-modules)
            CMD_RAMDISKMODULES=`parse_optbool "$*"`
            print_info 2 "CMD_RAMDISKMODULES: ${CMD_RAMDISKMODULES}"
            ;;
        --all-ramdisk-modules|--no-all-ramdisk-modules)
            CMD_ALLRAMDISKMODULES=`parse_optbool "$*"`
            print_info 2 "CMD_ALLRAMDISKMODULES: ${CMD_ALLRAMDISKMODULES}"
            ;;
        --callback=*)
            CMD_CALLBACK=`parse_opt "$*"`
            print_info 2 "CMD_CALLBACK: ${CMD_CALLBACK}/$*"
            ;;
        --static|--no-static)
            CMD_STATIC=`parse_optbool "$*"`
            print_info 2 "CMD_STATIC: ${CMD_STATIC}"
            ;;
        --tempdir=*)
            TMPDIR=`parse_opt "$*"`
            TEMP=${TMPDIR}/$RANDOM.$RANDOM.$RANDOM.$$
            print_info 2 "TMPDIR: ${TMPDIR}"
            print_info 2 "TEMP: ${TEMP}"
            ;;
        --postclear|--no-postclear)
            CMD_POSTCLEAR=`parse_optbool "$*"`
            print_info 2 "CMD_POSTCLEAR: ${CMD_POSTCLEAR}"
            ;;
        --arch-override=*)
            CMD_ARCHOVERRIDE=`parse_opt "$*"`
            print_info 2 "CMD_ARCHOVERRIDE: ${CMD_ARCHOVERRIDE}"
            ;;
        --color|--no-color)
            USECOLOR=`parse_optbool "$*"`
            print_info 2 "USECOLOR: ${USECOLOR}"
            setColorVars
            ;;
        --logfile=*)
            CMD_LOGFILE=`parse_opt "$*"`
            LOGFILE=`parse_opt "$*"`
            print_info 2 "CMD_LOGFILE: ${CMD_LOGFILE}"
            print_info 2 "LOGFILE: ${CMD_LOGFILE}"
            ;;
        --kerneldir=*)
            CMD_KERNEL_DIR=`parse_opt "$*"`
            print_info 2 "CMD_KERNEL_DIR: ${CMD_KERNEL_DIR}"
            ;;
        --kernel-config=*)
            CMD_KERNEL_CONFIG=`parse_opt "$*"`
            print_info 2 "CMD_KERNEL_CONFIG: ${CMD_KERNEL_CONFIG}"
            ;;
        --module-prefix=*)
            CMD_INSTALL_MOD_PATH=`parse_opt "$*"`
            print_info 2 "CMD_INSTALL_MOD_PATH: ${CMD_INSTALL_MOD_PATH}"
            ;;
        --cachedir=*)
            CACHE_DIR=`parse_opt "$*"`
            print_info 2 "CACHE_DIR: ${CACHE_DIR}"
            ;;
        --minkernpackage=*)
            CMD_MINKERNPACKAGE=`parse_opt "$*"`
            print_info 2 "MINKERNPACKAGE: ${CMD_MINKERNPACKAGE}"
            ;;
        --modulespackage=*)
            CMD_MODULESPACKAGE=`parse_opt "$*"`
            print_info 2 "MODULESPACKAGE: ${CMD_MODULESPACKAGE}"
            ;;
        --kerncache=*)
            CMD_KERNCACHE=`parse_opt "$*"`
            print_info 2 "KERNCACHE: ${CMD_KERNCACHE}"
            ;;
        --kernname=*)
            CMD_KERNNAME=`parse_opt "$*"`
            print_info 2 "KERNNAME: ${CMD_KERNNAME}"
            ;;
        --appendname=*)
            CMD_APPENDNAME=`parse_opt "$*"`
            print_info 2 "APPENDNAME: ${CMD_APPENDNAME}"
            ;;
        --symlink|--no-symlink)
            CMD_SYMLINK=`parse_optbool "$*"`
            print_info 2 "CMD_SYMLINK: ${CMD_SYMLINK}"
            ;;
        --kernel-sources|--no-kernel-sources)
            CMD_KERNEL_SOURCES=`parse_optbool "$*"`
            print_info 2 "CMD_KERNEL_SOURCES: ${CMD_KERNEL_SOURCES}"
            ;;
        --initramfs-overlay=*)
            CMD_INITRAMFS_OVERLAY=`parse_opt "$*"`
            print_info 2 "CMD_INITRAMFS_OVERLAY: ${CMD_INITRAMFS_OVERLAY}"
            ;;
        --linuxrc=*)
            CMD_LINUXRC=`parse_opt "$*"`
            print_info 2 "CMD_LINUXRC: ${CMD_LINUXRC}"
            ;;
        --busybox-config=*)
            CMD_BUSYBOX_CONFIG=`parse_opt "$*"`
            print_info 2 "CMD_BUSYBOX_CONFIG: ${CMD_BUSYBOX_CONFIG}"
            ;;
        --genzimage)
            KERNEL_MAKE_DIRECTIVE_2='zImage.initrd'
            KERNEL_BINARY_2='arch/powerpc/boot/zImage.initrd'
            CMD_GENZIMAGE="yes"
#           ENABLE_PEGASOS_HACKS="yes"
#           print_info 2 "ENABLE_PEGASOS_HACKS: ${ENABLE_PEGASOS_HACKS}"
            ;;
        --luks|--no-luks)
            CMD_LUKS=`parse_optbool "$*"`
            print_info 2 "CMD_LUKS: ${CMD_LUKS}"
            ;;
        --gpg|--no-gpg)
            CMD_GPG=`parse_optbool "$*"`
            print_info 2 "CMD_GPG: ${CMD_GPG}"
            ;;
        --firmware|--no-firmware)
            CMD_FIRMWARE=`parse_optbool "$*"`
            print_info 2 "CMD_FIRMWARE: ${CMD_FIRMWARE}"
            ;;
        --firmware-dir=*)
            CMD_FIRMWARE_DIR=`parse_opt "$*"`
            CMD_FIRMWARE=1
            print_info 2 "CMD_FIRMWARE_DIR: ${CMD_FIRMWARE_DIR}"
            ;;
        --firmware-files=*)
            CMD_FIRMWARE_FILES=`parse_opt "$*"`
            CMD_FIRMWARE=1
            print_info 2 "CMD_FIRMWARE_FILES: ${CMD_FIRMWARE_FILES}"
            ;;
        --integrated-initramfs|--no-integrated-initramfs)
            CMD_INTEGRATED_INITRAMFS=`parse_optbool "$*"`
            print_info 2 "CMD_INTEGRATED_INITRAMFS=${CMD_INTEGRATED_INITRAMFS}"
            ;;
        --compress-initramfs|--no-compress-initramfs|--compress-initrd|--no-compress-initrd)
            CMD_COMPRESS_INITRD=`parse_optbool "$*"`
            print_info 2 "CMD_COMPRESS_INITRD=${CMD_COMPRESS_INITRD}"
            ;;
        --compress-initramfs-type=*|--compress-initrd-type=*)
            COMPRESS_INITRD_TYPE=`parse_opt "$*"`
            print_info 2 "CMD_COMPRESS_INITRD_TYPE: ${CMD_LINUXRC}"
            ;;
        --config=*)
            print_info 2 "CMD_GK_CONFIG: `parse_opt "$*"`"
            ;;
        all)
            BUILD_KERNEL=1
            BUILD_MODULES=1
            BUILD_RAMDISK=1
            ;;
        ramdisk|initramfs)
            BUILD_RAMDISK=1
            ;;
        kernel)
            BUILD_KERNEL=1
            BUILD_MODULES=1
            BUILD_RAMDISK=0
            ;;
        bzImage)
            BUILD_KERNEL=1
            BUILD_MODULES=0
            BUILD_RAMDISK=1
            CMD_RAMDISKMODULES=0
            print_info 2 "CMD_RAMDISKMODULES: ${CMD_RAMDISKMODULES}"
            ;;
        --help)
            longusage
            exit 1
            ;;
        --version)
            echo "${GK_V}"
            exit 0
            ;;
        *)
            echo "Error: Unknown option '$*'!"
            exit 1
            ;;
    esac
}
