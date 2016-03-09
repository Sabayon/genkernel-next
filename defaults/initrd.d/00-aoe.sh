#!/bin/sh

. /etc/initrd.d/00-common.sh

start_aoe() {
    [ "${USE_AOE}" = "1" ] || return 0
    
    if [ ! -c /dev/etherd/discover ]; then
        bad_msg "Module aoe not loaded"
        return 0
    fi

    good_msg "Bringing up all interfaces for AOE discovery"
    for iface in /sys/class/net/* ; do ifconfig `basename $iface` up ; done

    for blk in $AOE_WAIT ; do
        good_msg "Waiting for $blk to be discovered"
	while [ ! -b "/dev/etherd/$blk" ] ; do
            echo > /dev/etherd/discover
	    sleep 1
	done
    done

    return 0
}

