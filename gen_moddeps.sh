#!/bin/bash

modules_kext()
{
	if [ "${PAT}" -gt "4" ]
	then
		KEXT=".ko"
	else
		KEXT=".o"
	fi
	echo ${KEXT}
}

modules_dep_list()
{
	KEXT=$(modules_kext)
	if [ -f ${INSTALL_MOD_PATH}/lib/modules/${KV}/modules.dep ]
	then
		cat ${INSTALL_MOD_PATH}/lib/modules/${KV}/modules.dep | grep ${1}${KEXT}\: | cut -d\:  -f2
	fi
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
	if [ "${ALLINITRDMODULES}" = "1" ]; then
		strip_mod_paths $(find "${INSTALL_MOD_PATH}/lib/modules/${KV}" -name "*$(modules_kext)") | sort
	else
		local group_modules	
		rm -f ${TEMP}/moddeps > /dev/null
	
		for group_modules in ${!MODULES_*}; do
			gen_deps ${!group_modules}
		done

		# Only list each module once
		if [ -f ${TEMP}/moddeps ]
		then
		    cat ${TEMP}/moddeps | sort | uniq
		fi
	fi
}
