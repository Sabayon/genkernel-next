#!/bin/sh

. /etc/initrd.d/00-splash.sh
. /etc/initrd.d/00-common.sh
. /etc/initrd.d/00-livecd.sh

setup_keymap() {
    if [ -z "${keymap}" ]; then
        return 0
    fi

    [ ! -e /dev/tty0 ] && ln -s /dev/tty1 /dev/tty0

    [ -f /lib/keymaps/keymapList ] && choose_keymap
}

choose_keymap() {
    good_msg "Loading keymaps"

    if [ -z "${keymap}" ]; then
        splashcmd verbose
        cat /lib/keymaps/keymapList
        read -t 10 -p '<< Load keymap (Enter for default): ' keymap
        case ${keymap} in
            1|azerty) keymap=azerty ;;
            2|be) keymap=be ;;
            3|bg) keymap=bg ;;
            4|br-a) keymap=br-a ;;
            5|br-l) keymap=br-l ;;
            6|by) keymap=by ;;
            7|cf) keymap=cf ;;
            8|croat) keymap=croat ;;
            9|cz) keymap=cz ;;
            10|de) keymap=de ;;
            11|dk) keymap=dk ;;
            12|dvorak) keymap=dvorak ;;
            13|es) keymap=es ;;
            14|et) keymap=et ;;
            15|fi) keymap=fi ;;
            16|fr) keymap=fr ;;
            17|gr) keymap=gr ;;
            18|hu) keymap=hu ;;
            19|il) keymap=il ;;
            20|is) keymap=is ;;
            21|it) keymap=it ;;
            22|jp) keymap=jp ;;
            23|la) keymap=la ;;
            24|lt) keymap=lt ;;
            25|mk) keymap=mk ;;
            26|nl) keymap=nl ;;
            27|no) keymap=no ;;
            28|pl) keymap=pl ;;
            29|pt) keymap=pt ;;
            30|ro) keymap=ro ;;
            31|ru) keymap=ru ;;
            32|se) keymap=se ;;
            33|sg) keymap=sg ;;
            34|sk-y) keymap=sk-y ;;
            35|sk-z) keymap=sk-z ;;
            36|slovene) keymap=slovene ;;
            37|trf) keymap=trf ;;
            38|trq) keymap=trq ;;
            39|ua) keymap=ua ;;
            40|uk) keymap=uk ;;
            41|us) keymap=us ;;
            42|wangbe) keymap=wangbe ;;
            43|sf|ch*) keymap=sf ;;
        esac
    fi

    if [ -e "/lib/keymaps/${keymap}.map" ]; then
        good_msg "Loading the ''${keymap}'' keymap"
        loadkmap < "/lib/keymaps/${keymap}.map"
        splashcmd set_msg "Set keymap to ${keymap}"
    elif [ -z "${keymap}" ]; then
        good_msg
        good_msg "Keeping default keymap"
        splashcmd set_msg "Keeping default keymap"
    else
        bad_msg "Sorry, but keymap ${keymap} is invalid"
        unset keymap
        choose_keymap
    fi
}
