#!/bin/bash

modules_dep_list()
{
	if [ "${PAT}" -gt "4" ]
	then
		KEXT=".ko"
	else
		KEXT=".o"
	fi
        cat /lib/modules/${KV}/modules.dep | grep ${1}${KEXT}\: | cut -d\:  -f2
}

# Pass module deps list
strip_mod_paths()
{
        local x
        local ret
        local myret

        for x in ${*}
        do
                ret=`basename ${x} | cut -d. -f1`
                myret="${myret} ${ret}"
        done
        echo "${myret}"
}


gen_deps()
{
	local modlist
	local deps

	for x in ${*}
	do
		echo ${x} >> ${TEMP}/moddeps
		modlist=`modules_dep_list ${x}`
		if [ "${modlist}" != "" -a "${modlist}" != " " ]
		then
			deps=`strip_mod_paths ${modlist}`
		else
			deps=""
		fi
		for y in ${deps}
		do
			echo ${y} >> ${TEMP}/moddeps
		done
	done
}

gen_dep_list()
{
	rm -f ${TEMP}/moddeps > /dev/null
	gen_deps ${STORAGE_MODULES}
	gen_deps ${FIREWIRE_MODULES}
	gen_deps ${ATARAID_MODULES}
	gen_deps ${PCMCIA_MODULES}
	gen_deps ${USB_MODULES}

	# Only list each module once
	cat ${TEMP}/moddeps | sort | uniq
}
