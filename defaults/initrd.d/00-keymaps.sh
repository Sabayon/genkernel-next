#!/bin/sh

. /etc/initrd.d/00-splash.sh
. /etc/initrd.d/00-common.sh
. /etc/initrd.d/00-livecd.sh

setup_keymap() {
    if [ -z "${USE_KEYMAP}" ]; then
        return 0
    fi

    [ ! -e /dev/tty0 ] && ln -s /dev/tty1 /dev/tty0

    [ -f /lib/keymaps/keymapList ] && choose_keymap
}

choose_keymap() {
    good_msg "Loading keyboard mappings"

    if [ -n "${DO_keymap}" ]; then
        splashcmd verbose
        cat /lib/keymaps/keymapList
        read -t 10 -p '<< Load keymap (Enter for default): ' USE_KEYMAP
    fi

    case ${USE_KEYMAP} in
        1|azerty) USE_KEYMAP=azerty ;;
        2|be) USE_KEYMAP=be ;;
        3|bg) USE_KEYMAP=bg ;;
        4|br-a) USE_KEYMAP=br-a ;;
        5|br-l) USE_KEYMAP=br-l ;;
        6|by) USE_KEYMAP=by ;;
        7|cf) USE_KEYMAP=cf ;;
        8|croat) USE_KEYMAP=croat ;;
        9|cz) USE_KEYMAP=cz ;;
        10|de) USE_KEYMAP=de ;;
        11|dk) USE_KEYMAP=dk ;;
        12|dvorak) USE_KEYMAP=dvorak ;;
        13|es) USE_KEYMAP=es ;;
        14|et) USE_KEYMAP=et ;;
        15|fi) USE_KEYMAP=fi ;;
        16|fr) USE_KEYMAP=fr ;;
        17|gr) USE_KEYMAP=gr ;;
        18|hu) USE_KEYMAP=hu ;;
        19|il) USE_KEYMAP=il ;;
        20|is) USE_KEYMAP=is ;;
        21|it) USE_KEYMAP=it ;;
        22|jp) USE_KEYMAP=jp ;;
        23|la) USE_KEYMAP=la ;;
        24|lt) USE_KEYMAP=lt ;;
        25|mk) USE_KEYMAP=mk ;;
        26|nl) USE_KEYMAP=nl ;;
        27|no) USE_KEYMAP=no ;;
        28|pl) USE_KEYMAP=pl ;;
        29|pt) USE_KEYMAP=pt ;;
        30|ro) USE_KEYMAP=ro ;;
        31|ru) USE_KEYMAP=ru ;;
        32|se) USE_KEYMAP=se ;;
        33|sg) USE_KEYMAP=sg ;;
        34|sk-y) USE_KEYMAP=sk-y ;;
        35|sk-z) USE_KEYMAP=sk-z ;;
        36|slovene) USE_KEYMAP=slovene ;;
        37|trf) USE_KEYMAP=trf ;;
        38|trq) USE_KEYMAP=trq ;;
        39|ua) USE_KEYMAP=ua ;;
        40|uk) USE_KEYMAP=uk ;;
        41|us) USE_KEYMAP=us ;;
        42|wangbe) USE_KEYMAP=wangbe ;;
        43|sf|ch*) USE_KEYMAP=sf ;;
    esac

    if [ -e "/lib/keymaps/${USE_KEYMAP}.map" ]; then
        good_msg "Loading the ''${USE_KEYMAP}'' keyboard mapping"
        loadkmap < "/lib/keymaps/${USE_KEYMAP}.map"
        splashcmd set_msg "Set keyboard mapping to ${USE_KEYMAP}"
    elif [ -z "${USE_KEYMAP}" ]; then
        good_msg "Keeping default keyboard mapping"
        splashcmd set_msg "Keeping default keyboard mapping"
    else
        bad_msg "Sorry, but keyboard mapping ${USE_KEYMAP} is invalid"
        unset USE_KEYMAP
        choose_keymap
    fi
}
