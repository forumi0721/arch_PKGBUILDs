#!/usr/bin/env bash

echo_white() {
	echo $'\e[01;0m'${1}$'\e[0m'${2}
}

echo_gray() {
	echo $'\e[01;30m'${1}$'\e[0m'${2}
}

echo_red() {
	echo $'\e[01;31m'${1}$'\e[0m'${2}
}

echo_green() {
	echo $'\e[01;32m'${1}$'\e[0m'${2}
}

echo_yellow() {
	echo $'\e[01;33m'${1}$'\e[0m'${2}
}

echo_blue() {
	echo $'\e[01;34m'${1}$'\e[0m'${2}
}

echo_violet() {
	echo $'\e[01;35m'${1}$'\e[0m '${2}
}

echo_cyan() {
	echo $'\e[01;36m'${1}$'\e[0m'${2}
}


#Function
fn_check_pkgbuild() {
	local retval=0

	local pkgbuild="${1}"
	local pkgbuilddir="$(dirname "${pkgbuild}")"

	local files=
	local list1=
	local list2=

	unset pkgname
	unset pkgver
	unset pkgrel
	unset arch
	unset epoch

	pushd . &>/dev/null

	cd "${pkgbuilddir}"

	source PKGBUILD

	if [ -z "${pkgname}" -o -z "${pkgver}" -o -z "${pkgrel}" -o -z "${arch}" ]; then
		echo_blue " -> " "$(dirname "${pkgbuild}")"
		echo_red "Cannot import PKGBUILD"
		echo
		popd &>/dev/null
		return 1
	fi

	local name=
	for name in ${pkgname[@]}
	do
		local subarch=
		for subarch in ${arch[@]}
		do
			if [ "${subarch}" != "any" -a "${subarch}" != "i686" -a "${subarch}" != "x86_64" -a "${subarch}" != "arm" -a "${subarch}" != "armv6h" -a "${subarch}" != "armv7h" ]; then
				continue
			fi
			if [ "${name}" = "netatalk" -a "${subarch/arm/}" != "${subarch}" ]; then
				continue
			fi
			if [ -z "${epoch}" ]; then
				files+=("$(echo ${name}-${pkgver}-${pkgrel}-${subarch}.pkg.tar.xz)")
			else
				files+=("$(echo ${name}-${epoch}:${pkgver}-${pkgrel}-${subarch}.pkg.tar.xz)")
			fi
		done
	done

	local file=
	for file in ${files[@]}
	do
		if [ ! -e "${file}" ]; then
			list1+=("$(echo ${file})")
		fi
	done

	local file=
	for file in $(ls *.pkg.tar.xz)
	do
		local valid=1
		local file2=
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

	if [ ${#list1[@]} -gt 1 -o ${#list2[@]} -gt 1 ]; then
		retval=1
		echo_blue " -> " "$(dirname "${pkgbuild}")"
		if [ ${#list1[@]} -gt 1 ]; then
			local list=
			for list in ${list1[@]}
			do
				if [ ! -z "${list}" ]; then
					echo_yellow "Package Not Found : " "${pkgbuilddir}/${list}"
				fi
			done
		fi
		if [ ${#list2[@]} -gt 1 ]; then
			local list=
			for list in ${list2[@]}
			do
				if [ ! -z "${list}" ]; then
					echo_red    "Invalid version   : " "${pkgbuilddir}/${list}"
				fi
			done
		fi
	fi

	popd &>/dev/null

	return "${retval}"
}

#Main
exitval=0

echo_green "==> " "Start - Checking packages..."

for pkgbuild in $(find . -type f -name PKGBUILD)
do
	fn_check_pkgbuild "${pkgbuild}"
	retval="${?}"
	if [ "${exitval}" = "0" -a "${retval}" != "0" ]; then
		exitval="${retval}"
	fi
	unset retval
done

echo_green "==> " "Done."
echo

exit "${exitval}"
