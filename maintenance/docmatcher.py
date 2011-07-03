#! /usr/bin/python
# Copyright (C) 2010 Gentoo Foundation
# Written by Sebastian Pipping <sebastian@pipping.org>
# Licensed under GPL v2 or later

from __future__ import print_function
import re
import sys
import os


NON_VARIABLES = ('UTF', 'USE', 'TCP', 'SMP', 'PXE', 'PPC', 'MAC',
	'GTK', 'GNU', 'CPU', 'DOS', 'NIC', 'NFS', 'ISO', 'TIMEOUT',
	'TFTP', 'SYSTEM', 'SPARC', 'RAID', 'LABEL', 'PROMPT', 'KERNEL',
	'GRP', 'DOCTYPE', 'DHCP', 'DEFAULT', 'ATARAID', 'APPEND')

NON_CONFIG_VARIABLES = ('BUILD_KERNEL', 'BUILD_MODULES', 'BUILD_RAMDISK',
	'TERM_COLUMNS', 'TERM_LINES', 'SPLASH_RES', 'TEMP')


EXTRA_VARIABLES = ['ARCH_OVERRIDE', 'BOOTLOADER', 'CLEAR_CACHE_DIR', 'DEFAULT_KERNEL_SOURCE', 'DISTDIR', 'GK_SHARE', 'BUSYBOX_APPLETS']
for app in ('DEVICE_MAPPER', 'UNIONFS_FUSE', 'BUSYBOX', 'DMRAID', 'LVM', 'ISCSI', 'FUSE', 'GPG', 'MDADM'):
	for prop in ('DIR', 'SRCTAR', 'VER'):
		EXTRA_VARIABLES.append('%s_%s' % (app, prop))
EXTRA_VARIABLES = tuple(EXTRA_VARIABLES)

IGNORE_OPTIONS = ('help', 'version')
_GPG_PARAMETERS = ('symmetric', )
IGNORE_PARAMETERS = _GPG_PARAMETERS
DEPRECATED_PARAMETERS = ('lvm2', 'gensplash', 'gensplash-res')


def exract_gen_cmdline_sh():
	f = open('gen_cmdline.sh', 'r')
	gen_cmdline_sh = f.read()
	f.close()

	usage_lines = list()
	parsing_lines = list()
	dest = None

	for line in gen_cmdline_sh.split('\n'):
		if line in ('longusage() {', 'usage() {'):
			dest = usage_lines
		elif line == 'parse_cmdline() {':
			dest = parsing_lines

		if dest is not None:
			dest.append(line)

		if line == '}':
			dest = None

	del gen_cmdline_sh


	parsing_code = '\n'.join(parsing_lines)
	del parsing_lines

	gen_cmdline_sh_parsing_long_params = set()
	for match in re.finditer('--([a-z][a-z0-9-]+)', parsing_code):
		para_name = match.group(1)
		if para_name in IGNORE_OPTIONS:
			continue
		if para_name in DEPRECATED_PARAMETERS:
			continue
		gen_cmdline_sh_parsing_long_params.add(para_name)

	gen_cmdline_sh_variables = set()
	for match in re.finditer('^\s*([A-Z_]+)=', parsing_code, re.MULTILINE):
		var_name = match.group(1)
		if var_name.startswith('CMD_'):
			continue
		if var_name in NON_CONFIG_VARIABLES:
			continue
		gen_cmdline_sh_variables.add(var_name)

	del parsing_code


	gen_cmdline_sh_usage_long_params = set()
	for match in re.finditer('--([a-z][a-z0-9-]+)', '\n'.join(usage_lines)):
		para_name = match.group(1)
		if para_name in IGNORE_OPTIONS:
			continue
		gen_cmdline_sh_usage_long_params.add(para_name)
	del usage_lines

	return gen_cmdline_sh_parsing_long_params, gen_cmdline_sh_usage_long_params, gen_cmdline_sh_variables


def extract_genkernel_8_txt():
	f = open(os.path.join('doc', 'genkernel.8.txt'), 'r')
	genkernel_8_txt = f.read()
	f.close()

	# Preprocess
	genkernel_8_txt = genkernel_8_txt.replace('*[*no-*]*','[no-]')

	yes_no = re.compile('^\\[(no-)\\]([a-z0-9-]+)$')

	genkernel_8_txt_long_params = set()
	for match in re.finditer('--((?:[a-z]|\\[no-\\])[a-z0-9-]+)', genkernel_8_txt):
		para_name = match.group(1)

		# Black list
		if para_name == 'no-':
			continue

		if para_name in IGNORE_PARAMETERS:
			continue

		m = yes_no.match(para_name)
		if m:
			p_yes = m.group(2)
			p_no = m.group(1) + m.group(2)
			genkernel_8_txt_long_params.add(p_yes)
			genkernel_8_txt_long_params.add(p_no)
		else:
			genkernel_8_txt_long_params.add(para_name)

	del genkernel_8_txt

	return genkernel_8_txt_long_params


def extract_genkernel_xml(genkernel_xml_path, variables_blacklist):
	f = open(genkernel_xml_path, 'r')
	genkernel_xml = f.read()
	f.close()

	# Preprocess
	genkernel_xml = genkernel_xml.replace('<c>','').replace('</c>','').replace('<b>','').replace('</b>','')

	yes_no = re.compile('^(no-)([a-z0-9-]+)$')

	genkernel_xml_long_params = set()
	for match in re.finditer('--([a-z][a-z0-9-]+)', genkernel_xml):
		para_name = match.group(1)

		if para_name in IGNORE_OPTIONS:
			continue

		# Fix doc error "--no install"
		if para_name == 'no':
			para_name = 'no-install'

		m = yes_no.match(para_name)
		if m and para_name != 'no-ramdisk-modules':
			p_yes = m.group(2)
			p_no = m.group(1) + m.group(2)
			genkernel_xml_long_params.add(p_yes)
			genkernel_xml_long_params.add(p_no)
		else:
			genkernel_xml_long_params.add(para_name)

	genkernel_xml_variables = set()
	for match in re.finditer('[A-Z_]{3,}', genkernel_xml):
		var_name = match.group(0)
		if var_name in variables_blacklist:
			continue
		genkernel_xml_variables.add(var_name)

	del genkernel_xml

	return genkernel_xml_long_params, genkernel_xml_variables


def extract_gen_determineargs_sh():
	f = open('gen_determineargs.sh', 'r')
	gen_determineargs_sh = f.read()
	f.close()

	gen_determineargs_sh_variables = set()
	for match in re.finditer('set_config_with_override\s+(?:BOOL|STRING)\s+([A-Z_]+)', gen_determineargs_sh):
		var_name = match.group(1)
		gen_determineargs_sh_variables.add(var_name)

	for match in re.finditer('([A-Z_]+)=`(?:arch|cache)_replace "\\$\\{\\1\\}"`', gen_determineargs_sh):
		var_name = match.group(1)
		gen_determineargs_sh_variables.add(var_name)

	del gen_determineargs_sh

	return gen_determineargs_sh_variables


def extract_genkernel_conf(variables_blacklist):
	f = open('genkernel.conf', 'r')
	genkernel_conf = f.read()
	f.close()

	genkernel_conf_variables = set()
	for match in re.finditer('^#*\\s*([A-Z_]{3,})', genkernel_conf, re.MULTILINE):
		var_name = match.group(1)
		if var_name in variables_blacklist:
			continue
		genkernel_conf_variables.add(var_name)

	del genkernel_conf

	return genkernel_conf_variables


def print_set(s):
	if s:
		print('\n'.join(('- ' + e) for e in sorted(s)))
	else:
		print('  NONE')
	print()


def  usage():
	print('USAGE: %s GENTOO/xml/htdocs/doc/en/genkernel.xml' % os.path.basename(sys.argv[0]))


def main():
	if len(sys.argv) != 2:
		usage()
		sys.exit(1)

	gen_cmdline_sh_parsing_long_params, gen_cmdline_sh_usage_long_params, gen_cmdline_sh_variables = exract_gen_cmdline_sh()
	genkernel_8_txt_long_params = extract_genkernel_8_txt()
	gen_determineargs_sh_variables = extract_gen_determineargs_sh()

	variables_blacklist = set(NON_VARIABLES).difference(gen_determineargs_sh_variables)
	known_variales = set(EXTRA_VARIABLES).union(gen_determineargs_sh_variables).union(gen_cmdline_sh_variables)

	genkernel_xml_long_params, genkernel_xml_variables = extract_genkernel_xml(sys.argv[1], variables_blacklist)
	genkernel_conf_variables = extract_genkernel_conf(variables_blacklist)


	# Status quo
	print('Options used by parser in *gen_cmdline.sh*:')
	print_set(gen_cmdline_sh_parsing_long_params)

	print('Options mentioned in usage of *gen_cmdline.sh*:')
	print_set(gen_cmdline_sh_usage_long_params)

	print('Options mentioned in *man page*:')
	print_set(genkernel_8_txt_long_params)

	print('Options mentioned in *web page*:')
	print_set(genkernel_xml_long_params)


	print('Variables set by *gen_cmdline.sh*:')
	print_set(gen_cmdline_sh_variables)

	print('Variables read by *gen_determineargs.sh*:')
	print_set(gen_determineargs_sh_variables)

	print('Variables mentioned in *web page*:')
	print_set(genkernel_xml_variables)

	print('Variables used in *genkernel.conf*:')
	print_set(genkernel_conf_variables)


	# Future work (due extensions)
	print('Variables missing from *web page*:')
	print_set(known_variales.difference(genkernel_xml_variables))

	print('Options missing from *web page*:')
	print_set(gen_cmdline_sh_parsing_long_params.difference(genkernel_xml_long_params))

	print('Variables missing from *genkernel.conf*:')
	print_set(known_variales.difference(genkernel_conf_variables))

	print('Options missing from the *man page*:')
	print_set(gen_cmdline_sh_parsing_long_params.difference(genkernel_8_txt_long_params))

	print('Options missing from *--help*:')
	print_set(gen_cmdline_sh_parsing_long_params.difference(gen_cmdline_sh_usage_long_params))


	# Future work (due removal and updates)
	print('Removed options still mentioned in the *man page*:')
	print_set(genkernel_8_txt_long_params.difference(gen_cmdline_sh_parsing_long_params))

	print('Removed options still mentioned in *--help*:')
	print_set(gen_cmdline_sh_usage_long_params.difference(gen_cmdline_sh_parsing_long_params))

	print('Removed options still mentioned in *web page*:')
	print_set(genkernel_xml_long_params.difference(gen_cmdline_sh_parsing_long_params))

	print('Removed variables still mentioned in *web page*:')
	print_set(genkernel_xml_variables.difference(known_variales))

	print('Removed variables still mentioned in *genkernel.conf*:')
	print_set(genkernel_conf_variables.difference(known_variales))


if __name__ == '__main__':
	main()
