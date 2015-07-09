#!/usr/bin/env bash

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
		echo ${1}
		if [ ${#list1[@]} -gt 1 ]; then
			for list in ${list1[@]}
			do
				if [ ! -z "${list}" ]; then
					echo "Need build : ${list}"
				fi
			done
		fi
		if [ ${#list2[@]} -gt 1 ]; then
			for list in ${list2[@]}
			do
				if [ ! -z "${list}" ]; then
					echo "Invalid : ${list}"
				fi
			done
		fi
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
