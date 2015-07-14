#!/usr/bin/env bash

echo_red() {
	echo -e "\e[0;31m${1}\e[0m"
}

echo_green() {
	echo -e "\e[0;32m${1}\e[0m"
}

echo_blue() {
	echo -e "\e[0;34m${1}\e[0m"
}

check() {
	local dir="$(dirname "${1}")"
	local files=
	local list1=
	local list2=

	unset pkgname
	unset pkgver
	unset pkgrel
	unset arch
	unset epoch

	pushd . &>/dev/null

	cd "${dir}"

	source PKGBUILD

	for name in ${pkgname[@]}
	do
		for arch in ${arch[@]}
		do
			if [ "${arch}" != "any" -a "${arch}" != "i686" -a "${arch}" != "x86_64" -a "${arch}" != "arm" -a "${arch}" != "armv6h" -a "${arch}" != "armv7h" ]; then
				continue
			fi
			if [ "${name}" = "netatalk" -a "${arch/arm/}" != "${arch}" ]; then
				continue
			fi
			if [ -z "${epoch}" ]; then
				files+=("$(echo ${name}-${pkgver}-${pkgrel}-${arch}.pkg.tar.xz)")
			else
				files+=("$(echo ${name}-${epoch}:${pkgver}-${pkgrel}-${arch}.pkg.tar.xz)")
			fi
		done
	done

	for file in ${files[@]}
	do
		if [ ! -e "${file}" ]; then
			list1+=("$(echo ${file})")
		fi
	done

	for file in $(ls *.pkg.tar.xz)
	do
		local valid=1
		for file2 in ${files[@]}
		do
			if [ "${file}" = "${file2}" ]; then
				valid=0
				break
			fi
		done
		if [ "${valid}" = "1" ]; then
			list2+=("${file}")
		fi
	done

	#echo ${1}
	if [ ${#list1[@]} -gt 1 -o ${#list2[@]} -gt 1 ]; then
		echo_green ${1}
		if [ ${#list1[@]} -gt 1 ]; then
			for list in ${list1[@]}
			do
				if [ ! -z "${list}" ]; then
					echo_red "Need build : ${list}"
				fi
			done
		fi
		if [ ${#list2[@]} -gt 1 ]; then
			for list in ${list2[@]}
			do
				if [ ! -z "${list}" ]; then
					echo_red "Invalid : ${list}"
				fi
			done
		fi
		echo
	fi

	popd &>/dev/null

	unset pkgname
	unset pkgver
	unset pkgrel
	unset arch
	unset epoch
}

for pkg in $(find . -name PKGBUILD)
do
	check "${pkg}"
done
