#!/bin/sh

function CheckVersion {
	local retvalue=
	local pkgfile="${1}"
	local pkgdir="$(dirname "${pkgfile}")"

	echo "Package Path : ${pkgdir}"

	#Get current version
	if [ ! -e "${pkgfile}" ]; then
		echo "Cannot find PKGBUILD"
		echo
		return 1
	fi

	if [ ! -z "$(grep '^_localpkgver=Y$' "${pkgfile}")" ]; then
		echo "Skip"
		echo
		return 1 
	fi

	local pkgver1="$(grep '^pkgver=' "${pkgfile}" | cut -f 2 -d '=')"
	if [ -z "${pkgver1}" ]; then
		echo "Cannot get pkgver in PKGBUILD"
		echo
		return 1 
	fi

	#Import function
	echo "Import settings..."

	local sourcetype=
	local sourcepath=

	unset OWNER
	unset SOURCETYPE
	unset SOURCEPATH
	unset -f GetSourcePatch

	if [ -e "${pkgdir}/SOURCE" ]; then
		L_ENV_DISABLE_PROMPT=1 source "${pkgdir}/SOURCE"
		if [ "${OWNER}" = "Y" ]; then
			sourcetype="local"
			sourcepath="${pkgdir}"
		else
			sourcetype=${SOURCETYPE}
			sourcepath=${SOURCEPATH}
		fi
	else
		sourcetype="local"
		sourcepath="${pkgdir}"
	fi

	echo "Done"

	#GetSource
	echo "Get source..."

	local tempdir="$(mktemp -d)"
	local downloadpath="$(Download "${tempdir}" "${sourcetype}" "${sourcepath}")"
	if [ "$?" != "0" ] || [ ! -e "${downloadpath}" ]; then
		echo ${downloadpath}
		rm -rf "${tempdir}"
		return 1
	fi

	echo "Done"

	#GetNewPkgversion
	echo "Get new version..."

	ProcessPkgVer "${downloadpath}"
	local pkgver2="$(GetNewVersion "${downloadpath}")"

	echo "Done"

	#Check
	echo "Compare version..."

	if [ ! -z "$(echo "${pkgver2}" | grep "$(date +'%Y%m%d')\.[0-9]\+")" ]; then
		echo "Date type pkgver"
		echo
		rm -rf "${tempdir}"
		rm -rf /var/tmp/makepkg-${USER}
		return 1
	fi

	if [ "${pkgver1}" = "${pkgver2}" ]; then
		retvalue=0
		echo "Already up-to-date."
	else
		retvalue=2
		echo "Update..."
		pushd . &> /dev/null
		cd "${pkgdir}"
		for f in $(ls -a --ignore=. --ignore=.. --ignore=*.pkg.tar.* --ignore=SOURCE)
		do
			rm -rf ${f}
		done
		popd &> /dev/null
		pushd . &> /dev/null
		cd "${pkgdir}"
		for f in $(ls -a --ignore=. --ignore=.. --ignore=*.pkg.tar.* --ignore=SOURCE --ignore=.svn --ignore=.git "${downloadpath}")
		do
			cp -ar "${downloadpath}/${f}" ./
		done
		if [ ! -z "$(declare -f GetSourcePatch)" ]; then
			echo "Apply patch..."
			GetSourcePatch
		fi
		popd &> /dev/null
	fi

	echo "Done"

	#Cleanup
	echo "Cleanup..."
	rm -rf /var/tmp/makepkg-${USER}
	rm -rf "${tempdir}"
	unset SOURCETYPE
	unset SOURCEPATH
	unset -f GetSourcePatch
	echo "Done"

	echo

	return ${retvalue}
}

function Download {
	local retvalue=
	local tempdir="${1}"
	local sourcetype="${2}"
	local sourcepath="${3}"
	local sourcebase="$(basename "${sourcepath}")"

	if [ "${sourcetype}" = "ABS" ]; then
		if [ ! -e "${sourcepath}" ]; then
			echo "Cannot find source"
			return 1
		fi
		cp -r "${sourcepath}" "${tempdir}/"
		pushd . &> /dev/null
		cd "${tempdir}"
		retvalue=$(ls -d */ | cut -d '/' -f 1)
		popd &> /dev/null
	elif [ "${sourcetype}" = "AUR" ]; then
		for cnt in {1..10}
		do
			wget "${sourcepath}" -O "${tempdir}/${sourcebase}" &> /dev/null
			if [ "$?" = "0" ]; then
				break;
			fi
			rm -rf "${tempdir}/${sourcebase}"
		done
		if [ ! -e "${tempdir}/${sourcebase}" ]; then
			echo "Cannot get source"
			return 1
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
		for cnt in {1..10}
		do
			svn co "${sourcepath}" "${sourcebase}" &> /dev/null
			if [ "$?" = "0" ]; then
				break;
			fi
			rm -rf "${tempdir}/${sourcebase}"
		done
		if [ ! -e "${tempdir}/${sourcebase}" ]; then
			echo "Cannot get source"
			popd &> /dev/null
			return 1
		fi
		retvalue="${sourcebase}"
		popd &> /dev/null
	elif [ "${sourcetype}" = "GIT" ]; then
		pushd . &> /dev/null
		cd "${tempdir}"
		for cnt in {1..10}
		do
			git clone "${sourcepath}" "${sourcebase}"
			if [ "$?" = "0" ]; then
				break;
			fi
		done
		if [ ! -e "${sourcebase}" ]; then
			echo "Cannot get source"
			popd &> /dev/null
			return 1
		fi
		retvalue="${sourcebase}"
		popd &> /dev/null
	elif [ "${sourcetype}" = "local" ]; then
		if [ ! -e "${sourcepath}" ]; then
			echo "Cannot find source"
			return 1
		fi
		pushd . &> /dev/null
		mkdir -p "${tempdir}/${sourcebase}"
		cd "${sourcepath}"
		for f in $(ls -a --ignore=. --ignore=.. --ignore=*.pkg.tar.* --ignore=SOURCE)
		do
			cp -ar "${f}" "${tempdir}/${sourcebase}/"
		done
		popd &> /dev/null
		retvalue="${sourcebase}"
	else
		echo "Unknown source type"
		return 1
	fi

	echo "${tempdir}/${retvalue}"

	return 0
}

function ProcessPkgVer {
	local retvalue=
	local downloadpath="${1}"

	pushd . &> /dev/null
	cd "${downloadpath}"
	
	unset pkgver
	unset -f pkgver
	alias eval="echo"
	L_ENV_DISABLE_PROMPT=1 source ./PKGBUILD &> /dev/null
	unalias eval
	if [ ! -z "$(declare -f pkgver)" ]; then
		echo "Process makepkg..."
		BUILDDIR=/var/tmp/makepkg-${USER} SRCDEST=/var/tmp/makepkg-${USER} makepkg --nobuild -Acdf &> /dev/null
		echo "Done"
	fi
	unset pkgver
	unset -f pkgver

	popd &> /dev/null

	return 0
}

function GetNewVersion {
	local retvalue=
	local downloadpath="${1}"

	pushd . &> /dev/null
	cd "${downloadpath}"
	
	retvalue="$(grep '^pkgver=' PKGBUILD | cut -f 2 -d '=')"
	popd &> /dev/null

	echo "${retvalue}"

	return 0
}

UPDATE_LIST=
for src in $(find . -name PKGBUILD | sort)
do
	CheckVersion "${src}"
	if [ "$?" = "2" ]; then
		UPDATE_LIST+=("${src}")
	fi
done

if [ ! -z "${UPDATE_LIST}" ]; then
	echo "Update List"
	for update in ${UPDATE_LIST[@]}
	do
		echo "${update}"
	done
fi

exit 0

