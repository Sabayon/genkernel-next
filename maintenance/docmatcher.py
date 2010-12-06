#! /usr/bin/python
# Copyright (C) 2010 Gentoo Foundation
# Written by Sebastian Pipping <sebastian@pipping.org>
# Licensed under GPL v2 or later

from __future__ import print_function
import re
import sys
import os


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


	gen_cmdline_sh_parsing_long_params = set()
	for match in re.finditer('--([a-z][a-z0-9-]+)', '\n'.join(parsing_lines)):
		para_name = match.group(1)
		gen_cmdline_sh_parsing_long_params.add(para_name)
	del parsing_lines


	gen_cmdline_sh_usage_long_params = set()
	for match in re.finditer('--([a-z][a-z0-9-]+)', '\n'.join(usage_lines)):
		para_name = match.group(1)
		gen_cmdline_sh_usage_long_params.add(para_name)
	del usage_lines
	
	return gen_cmdline_sh_parsing_long_params, gen_cmdline_sh_usage_long_params


def extract_genkernel_8():
	f = open('genkernel.8', 'r')
	genkernel_8 = f.read()
	f.close()

	# Preprocess
	genkernel_8 = genkernel_8.replace('\\fR','').replace('\\fB','').replace('\\-','-')

	yes_no = re.compile('^\\[(no-)\\]([a-z0-9-]+)$')

	genkernel_8_long_params = set()
	for match in re.finditer('--((?:[a-z]|\\[no-\\])[a-z0-9-]+)', genkernel_8):
		para_name = match.group(1)
		
		# Black list
		if para_name == 'no-':
			continue

		m = yes_no.match(para_name)
		if m:
			p_yes = m.group(2)
			p_no = m.group(1) + m.group(2)
			genkernel_8_long_params.add(p_yes)
			genkernel_8_long_params.add(p_no)
		else:
			genkernel_8_long_params.add(para_name)

	del genkernel_8
	
	return genkernel_8_long_params


def extract_genkernel_xml(genkernel_xml_path):
	f = open(genkernel_xml_path, 'r')
	genkernel_xml = f.read()
	f.close()

	# Preprocess
	genkernel_xml = genkernel_xml.replace('<c>','').replace('</c>','').replace('<b>','').replace('</b>','')

	yes_no = re.compile('^(no-)([a-z0-9-]+)$')

	genkernel_xml_long_params = set()
	for match in re.finditer('--([a-z][a-z0-9-]+)', genkernel_xml):
		para_name = match.group(1)
		
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

	del genkernel_xml
	
	return genkernel_xml_long_params


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

	gen_cmdline_sh_parsing_long_params, gen_cmdline_sh_usage_long_params = exract_gen_cmdline_sh()
	genkernel_8_long_params = extract_genkernel_8()
	genkernel_xml_long_params = extract_genkernel_xml(sys.argv[1])


	# Status quo
	print('Used by parser in *gen_cmdline.sh*:')
	print_set(gen_cmdline_sh_parsing_long_params)

	print('Mentioned in usage of *gen_cmdline.sh*:')
	print_set(gen_cmdline_sh_usage_long_params)
	
	print('Mentioned in *man page*:')
	print_set(genkernel_8_long_params)

	print('Mentioned in *web page*:')
	print_set(genkernel_xml_long_params)


	# Future work
	print('Options missing from the *man page*:')
	print_set(gen_cmdline_sh_parsing_long_params.difference(genkernel_8_long_params))

	print('Removed options still mentioned in the *man page*:')
	print_set(genkernel_8_long_params.difference(gen_cmdline_sh_parsing_long_params))


	print('Options missing from *--help*:')
	print_set(gen_cmdline_sh_parsing_long_params.difference(gen_cmdline_sh_usage_long_params))

	print('Removed options still mentioned in *--help*:')
	print_set(gen_cmdline_sh_usage_long_params.difference(gen_cmdline_sh_parsing_long_params))


	print('Options missing from *web page*:')
	print_set(gen_cmdline_sh_parsing_long_params.difference(genkernel_xml_long_params))

	print('Removed options still mentioned in *web page*:')
	print_set(genkernel_xml_long_params.difference(gen_cmdline_sh_parsing_long_params))


if __name__ == '__main__':
	main()
