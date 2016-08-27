#!/usr/bin/env bash

echo_white() {
	echo $'\e[01;0m'"${1}"$'\e[0m'"${2}"
}

echo_gray() {
	echo $'\e[01;30m'"${1}"$'\e[0m'"${2}"
}

echo_red() {
	echo $'\e[01;31m'"${1}"$'\e[0m'"${2}"
}

echo_green() {
	echo $'\e[01;32m'"${1}"$'\e[0m'"${2}"
}

echo_yellow() {
	echo $'\e[01;33m'"${1}"$'\e[0m'"${2}"
}

echo_blue() {
	echo $'\e[01;34m'"${1}"$'\e[0m'"${2}"
}

echo_violet() {
	echo $'\e[01;35m'"${1}"$'\e[0m '"${2}"
}

echo_cyan() {
	echo $'\e[01;36m'"${1}"$'\e[0m'"${2}"
}


#Function
fn_check_version() {
	local retvalue=0

	pushd . &>/dev/null
	cd "${1}"
	local pkgfile="$(pwd)/PKGBUILD"
	local pkgdir="$(pwd)"
	popd &> /dev/null

	rm -rf /var/tmp/makepkg-repo-${USER}

	#Validation
	if [ -e "/var/tmp/makepkg-repo-${USER}" ]; then
		echo_red "Cannot delete /var/tmp/makepkg-repo-${USER}"
		return 1
	fi

	if [ -e "${pkgdir}/SOURCE" ]; then
		if [ ! -z "$(grep '^HOLDPKGVER="Y"$' ${pkgdir}/SOURCE)" ]; then
			echo_yellow " -> " "Skip (HOLDPKGVER=Y)"
			return 1 
		fi
		if [ ! -z "$(grep '^HOLDPKGVER=Y$' ${pkgdir}/SOURCE)" ]; then
			echo_yellow " -> " "Skip (HOLDPKGVER=Y)"
			return 1 
		fi
	fi

	#Get current pkgver
	local pkgver1="$(grep '^pkgver=' "${pkgfile}" | cut -f 2 -d '=')"
	if [ -z "${pkgver1}" ]; then
		echo_red "Cannot get pkgver in PKGBUILD"
		return 1 
	fi

	#Import setting
	echo_blue " -> " "Import setting..."

	local sourcetype=
	local sourcepath=

	unset SOURCETYPE
	unset SOURCEPATH
	unset -f GetSourcePatch
	unset -f CheckUpdate

	if [ -e "${pkgdir}/SOURCE" ]; then
		L_ENV_DISABLE_PROMPT=1 source "${pkgdir}/SOURCE"

		if [ "${HOLDPKGVER}" = "Y" ]; then
			echo_yellow " -> " "Skip (HOLDPKGVER=Y)"
			return 1 
		fi

		sourcetype=${SOURCETYPE}
		if [ "${sourcetype}" = "local" ]; then
			sourcepath="${pkgdir}"
		else
			sourcepath="${SOURCEPATH}"
		fi
	fi

	if [ -z "${sourcetype}" ]; then
		sourcetype="local"
	fi
	if [ -z "${sourcepath}" ]; then
		sourcepath="${pkgdir}"
	fi

	#GetSource
	echo_blue " -> " "Get source..."

	local tempdir="$(mktemp -p /var/tmp -d)"
	local downloadpath="$(fn_download "${pkgdir}" "${tempdir}" "${sourcetype}" "${sourcepath}")"
	if [ "$?" = "1" ]; then
		echo_red "Cannot find source"
		rm -rf "${tempdir}" "${downloadpath}"
		return 1
	elif [ "$?" = "2" ]; then
		echo_red "Cannot get source"
		rm -rf "${tempdir}" "${downloadpath}"
		return 1
	elif [ "$?" = "3" ]; then
		echo_red "Unknown source type"
		rm -rf "${tempdir}" "${downloadpath}"
		return 1
	fi

	if [ ! -e "${downloadpath}" ]; then
		echo_red "Cannot found download path : ${downloadpath}"
		rm -rf "${tempdir}" "${downloadpath}"
		return 1
	fi
	if [ ! -e "${downloadpath}/PKGBUILD" ]; then
		echo_red "Cannot found download path : ${downloadpath}"
		rm -rf "${tempdir}" "${downloadpath}"
		return 1
	fi

	#GetNewPkgversion
	echo_blue " -> " "Get new version..."

	pushd . &> /dev/null
	cd "${downloadpath}"
	
	if [ ! -z "$(declare -f CheckUpdate)" ]; then
		echo_yellow " -> " "Check Update..."
		CheckUpdate
	fi
	if [ ! -z "$(declare -f GetSourcePatch)" ]; then
		echo_yellow " -> " "Apply patch..."
		GetSourcePatch
	fi

	unset pkgver
	unset -f pkgver
	alias eval="echo"
	L_ENV_DISABLE_PROMPT=1 source ./PKGBUILD &> /dev/null
	unalias eval
	if [ ! -z "$(declare -f pkgver)" ]; then
		echo_yellow " -> " "Execute makepkg..."
		#mkdir -p /var/tmp/makepkg-repo-build-${USER} /var/tmp/makepkg-repo-src-${USER}
		#BUILDDIR=/var/tmp/makepkg-repo-build-${USER} SRCDEST=/var/tmp/makepkg-repo-src-${USER} makepkg --nobuild -Acdf &> /dev/null
		pushd . &> /dev/null
		mkdir -p /var/tmp/makepkg-repo-${USER}
		cp -ar "${downloadpath}" /var/tmp/makepkg-repo-${USER}/build
		cd /var/tmp/makepkg-repo-${USER}/build
		makepkg --nobuild -Acdf &> /dev/null
		#makepkg --nobuild -Acdf
		if [ "$?" != "0" ]; then
			echo_red "makepkg failed"
			exit
			popd &> /dev/null
			popd &> /dev/null
			rm -rf "${tempdir}" "/var/tmp/makepkg-repo-${USER}"
			return 1
		else
			cp -f /var/tmp/makepkg-repo-${USER}/build/PKGBUILD "${downloadpath}/PKGBUILD"
		fi
		popd &> /dev/null
	fi
	unset pkgver
	unset -f pkgver

	popd &> /dev/null

	#Check
	echo_blue " -> " "Compare version..."

	pushd . &> /dev/null
	cd "${downloadpath}"

	local pkgver2="$(grep '^pkgver=' PKGBUILD | cut -f 2 -d '=')"
	if [ -z "${pkgver2}" ]; then
		echo_red "Cannot get pkgver in PKGBUILD"
		popd &> /dev/null
		rm -rf "${tempdir}" "/var/tmp/makepkg-repo-${USER}"
		return 1 
	fi

	popd &> /dev/null

	#if [ "${pkgver1}" = "${pkgver2}" ]; then
	diff "${pkgfile}" "${downloadpath}/PKGBUILD" &> /dev/null
	if [ "${?}" = "0" ]; then
		retvalue=0
		echo_blue " -> " "Already up-to-date."
	else
		retvalue=2
		echo_cyan " -> " "Current version : ${pkgver1}"
		echo_cyan " -> " "New version : ${pkgver2}"
		echo_yellow " -> " "Update..."
		pushd . &> /dev/null
		cd "${pkgdir}"
		local f=
		for f in $(ls -a --ignore=. --ignore=.. --ignore=*.pkg.tar.* --ignore=*.src.tar.* --ignore=*.bin.tar.* --ignore=SOURCE)
		do
			rm -rf ${f}
		done
		popd &> /dev/null
		pushd . &> /dev/null
		cd "${pkgdir}"
		local f=
		for f in $(ls -a --ignore=. --ignore=.. --ignore=*.pkg.tar.* --ignore=*.src.tar.* --ignore=*.bin.tar.* --ignore=SOURCE --ignore=.svn --ignore=.git "${downloadpath}")
		do
			cp -ar "${downloadpath}/${f}" ./
		done
		#if [ ! -z "$(declare -f GetSourcePatch)" ]; then
		#	echo_yellow " -> " "Apply patch..."
		#	GetSourcePatch
		#fi
		popd &> /dev/null
	fi

	#Cleanup
	echo_blue " -> " "Cleanup..."
	rm -rf "${tempdir}" "/var/tmp/makepkg-repo-${USER}"
	unset SOURCETYPE
	unset SOURCEPATH
	unset -f GetSourcePatch

	return ${retvalue}
}

#Function
fn_download() {
	local retvalue=
	local pkgdir="${1}"
	local tempdir="${2}"
	local sourcetype="${3}"
	local sourcepath="${4}"
	local sourcebase=
	if [ "${sourcetype}" = "AUR4" ]; then
		sourcebase="$(basename "${pkgdir}")"
	else
		sourcebase="$(basename "${sourcepath}")"
	fi

	if [ "${sourcetype}" = "ABS" ]; then
		if [ ! -e "${sourcepath}" ]; then
			#echo "Cannot find source"
			return 1
		fi
		cp -r "${sourcepath}" "${tempdir}/"
		pushd . &> /dev/null
		cd "${tempdir}"
		retvalue=$(ls -d */ | cut -d '/' -f 1)
		popd &> /dev/null
	elif [ "${sourcetype}" = "RSYNC" ]; then
		pushd . &> /dev/null
		cd "${tempdir}"
		local cnt=
		for cnt in {1..10}
		do
			rsync -mrt "${sourcepath}"/* "${sourcebase}" &> /dev/null
			if [ "$?" = "0" ]; then
				break;
			fi
			rm -rf "${tempdir}/${sourcebase}"
		done
		if [ ! -e "${tempdir}/${sourcebase}" ]; then
			#echo "Cannot get source"
			popd &> /dev/null
			return 2
		fi
		retvalue="${sourcebase}"
		popd &> /dev/null
	elif [ "${sourcetype}" = "AUR" ]; then
		local cnt=
		for cnt in {1..10}
		do
			wget "${sourcepath}" -O "${tempdir}/${sourcebase}" &> /dev/null
			if [ "$?" = "0" ]; then
				break;
			fi
			rm -rf "${tempdir}/${sourcebase}"
		done
		if [ ! -e "${tempdir}/${sourcebase}" ]; then
			#echo "Cannot get source"
			return 2
		fi
		pushd . &> /dev/null
		cd "${tempdir}"
		bsdtar -xf "${tempdir}/${sourcebase}"
		rm -rf "${tempdir}/${sourcebase}"
		retvalue=$(ls -d */ | cut -d '/' -f 1)
		popd &> /dev/null
	elif [ "${sourcetype}" = "AUR4" ]; then
		local cnt=
		for cnt in {1..10}
		do
			git clone --depth=1 "${sourcepath}" "${tempdir}/${sourcebase}" &> /dev/null
			if [ "$?" = "0" ]; then
				break;
			fi
			rm -rf "${tempdir}/${sourcebase}"
		done
		if [ ! -e "${tempdir}/${sourcebase}" ]; then
			#echo "Cannot get source"
			return 2
		fi
		pushd . &> /dev/null
		cd "${tempdir}"
		retvalue=$(ls -d */ | cut -d '/' -f 1)
		popd &> /dev/null
	elif [ "${sourcetype}" = "SVN" ]; then
		pushd . &> /dev/null
		cd "${tempdir}"
		local cnt=
		for cnt in {1..10}
		do
			svn co "${sourcepath}" "${sourcebase}" &> /dev/null
			if [ "$?" = "0" ]; then
				break;
			fi
			rm -rf "${tempdir}/${sourcebase}"
		done
		if [ ! -e "${tempdir}/${sourcebase}" ]; then
			#echo "Cannot get source"
			popd &> /dev/null
			return 2
		fi
		retvalue="${sourcebase}"
		popd &> /dev/null
	elif [ "${sourcetype}" = "GIT" ]; then
		pushd . &> /dev/null
		cd "${tempdir}"
		local cnt=
		for cnt in {1..10}
		do
			git clone "${sourcepath}" "${sourcebase}"
			if [ "$?" = "0" ]; then
				break;
			fi
		done
		if [ ! -e "${sourcebase}" ]; then
			#echo "Cannot get source"
			popd &> /dev/null
			return 2
		fi
		retvalue="${sourcebase}"
		popd &> /dev/null
	elif [ "${sourcetype}" = "local" ]; then
		if [ ! -e "${sourcepath}" ]; then
			#echo "Cannot find source"
			return 1
		fi
		pushd . &> /dev/null
		mkdir -p "${tempdir}/${sourcebase}"
		cd "${sourcepath}"
		local f=
		for f in $(ls -a --ignore=. --ignore=.. --ignore=*.pkg.tar.* --ignore=SOURCE)
		do
			cp -ar "${f}" "${tempdir}/${sourcebase}/"
		done
		popd &> /dev/null
		retvalue="${sourcebase}"
	else
		#echo "Unknown source type"
		return 3
	fi

	echo "${tempdir}/${retvalue}"

	return 0
}


#Main
UPDATE_LIST=
for src in $(find . -name PKGBUILD -not -path "./arch_meta_PKGBUILDs/*" | sort)
do
	srcdir="$(dirname "${src}")"

	echo_green "==> " "Start - ${srcdir}"

	fn_check_version "${srcdir}"
	if [ "$?" = "2" ]; then
		UPDATE_LIST+=("${srcdir}")
	fi

	echo_green "==> " "Done."
	echo
done

if [ ${#UPDATE_LIST[@]} -gt 1 ]; then
	echo
	echo
	echo_green "==> " "Update List"
	for update in ${UPDATE_LIST[@]}
	do
		if [ ! -z "${update}" ]; then
			echo_cyan " -> " "${update}"
		fi
	done
	echo_green "==> " "Done."
	echo
fi

exit 0

