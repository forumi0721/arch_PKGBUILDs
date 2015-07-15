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
fn_check_version() {
	local retvalue=0

	local pkgfile="${1}"
	local pkgdir="$(dirname "${pkgfile}")"

	rm -rf /var/tmp/makepkg-repo-build-${USER} /var/tmp/makepkg-repo-src-${USER}

	#Validation
	if [ -e "/var/tmp/makepkg-repo-build-${USER}" ]; then
		echo_red "Cannot delete /var/tmp/makepkg-repo-build-${USER}"
		return 1
	fi
	if [ -e "/var/tmp/makepkg-repo-src-${USER}" ]; then
		echo_red "Cannot delete /var/tmp/makepkg-repo-src-${USER}"
		return 1
	fi

	if [ -e "${pkgdir}/SOURCE" ]; then
		if [ ! -z "$(grep '^LOCALPKGVER="Y"$' ${pkgdir}/SOURCE)" ]; then
			echo_yellow " -> " "Skip (LOCALPKGVER=Y)"
			return 1 
		fi
		if [ ! -z "$(grep '^LOCALPKGVER=Y$' ${pkgdir}/SOURCE)" ]; then
			echo_yellow " -> " "Skip (LOCALPKGVER=Y)"
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

	if [ -e "${pkgdir}/SOURCE" ]; then
		L_ENV_DISABLE_PROMPT=1 source "${pkgdir}/SOURCE"

		if [ "${LOCALPKGVER}" = "Y" ]; then
			echo_yellow " -> " "Skip (LOCALPKGVER=Y)"
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
	local downloadpath="$(fn_download "${tempdir}" "${sourcetype}" "${sourcepath}")"
	if [ "$?" = "1" ]; then
		echo_red "Cannot find source"
		rm -rf "${tempdir}"
		return 1
	elif [ "$?" = "2" ]; then
		echo_red "Cannot get source"
		rm -rf "${tempdir}"
		return 1
	elif [ "$?" = "3" ]; then
		echo_red "Unknown source type"
		rm -rf "${tempdir}"
		return 1
	fi

	if [ ! -e "${downloadpath}" ]; then
		echo_red "Cannot found download path : ${downloadpath}"
		rm -rf "${tempdir}"
		return 1
	fi

	#GetNewPkgversion
	echo_blue " -> " "Get new version..."

	pushd . &> /dev/null
	cd "${downloadpath}"
	
	unset pkgver
	unset -f pkgver
	alias eval="echo"
	L_ENV_DISABLE_PROMPT=1 source ./PKGBUILD &> /dev/null
	unalias eval
	if [ ! -z "$(declare -f pkgver)" ]; then
		echo_yellow " -> " "Execute makepkg..."
		mkdir -p /var/tmp/makepkg-repo-build-${USER} /var/tmp/makepkg-repo-src-${USER}
		BUILDDIR=/var/tmp/makepkg-repo-build-${USER} SRCDEST=/var/tmp/makepkg-repo-src-${USER} makepkg --nobuild -Acdf &> /dev/null
		if [ "$?" != "0" ]; then
			echo_red "makepkg failed"
			rm -rf "${tempdir}" "/var/tmp/makepkg-repo-build-${USER}" "/var/tmp/makepkg-repo-src-${USER}"
			return 1
		fi
	fi
	unset pkgver
	unset -f pkgver

	local pkgver2="$(grep '^pkgver=' PKGBUILD | cut -f 2 -d '=')"
	if [ -z "${pkgver2}" ]; then
		echo_red "Cannot get pkgver in PKGBUILD"
		rm -rf "${tempdir}" "/var/tmp/makepkg-repo-build-${USER}" "/var/tmp/makepkg-repo-src-${USER}"
		return 1 
	fi

	popd &> /dev/null

	#Check
	echo_blue " -> " "Compare version..."

	if [ "${pkgver1}" = "${pkgver2}" ]; then
		retvalue=0
		echo_blue " -> " "Already up-to-date."
	else
		retvalue=2
		echo_cyan " -> " "Current version : ${pkgver1}"
		echo_cyan " -> " "New version : ${pkgver1}"
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
		if [ ! -z "$(declare -f GetSourcePatch)" ]; then
			echo_yellow " -> " "Apply patch..."
			GetSourcePatch
		fi
		popd &> /dev/null
	fi

	#Cleanup
	echo_blue " -> " "Cleanup..."
	rm -rf "${tempdir}" "/var/tmp/makepkg-repo-build-${USER}" "/var/tmp/makepkg-repo-src-${USER}"
	unset SOURCETYPE
	unset SOURCEPATH
	unset -f GetSourcePatch

	return ${retvalue}
}

#Function
fn_download() {
	local retvalue=
	local tempdir="${1}"
	local sourcetype="${2}"
	local sourcepath="${3}"
	local sourcebase="$(basename "${sourcepath}")"

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

	fn_check_version "${src}"
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

