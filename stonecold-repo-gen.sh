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

#Validation
if [ -z "$(which repo-add 2> /dev/null)" ]; then
	echo "command not found : repo-add"
	exit 1
fi

#Variable
REPO_NAME="StoneCold"
LOCAL_REPO="stonecold-repo"
TARGET_ARCH=("i686" "x86_64" "arm" "armv6h" "armv7h")
PKGS="pkgs"
FINDOPTION="-name \"*-any.pkg.tar.*\""
for arch in ${TARGET_ARCH[@]}
do
	FINDOPTION="${FINDOPTION} -o -name \"*-${arch}.pkg.tar.*\""
done

#Function
function GenerateRepo {
	if [ ! -d "${LOCAL_REPO}" ]; then
		rm -rf "${LOCAL_REPO}"
		echo_blue "Make directory - ${LOCAL_REPO}"
		mkdir -p "${LOCAL_REPO}"
	fi

	if [ ! -d "${LOCAL_REPO}/${PKGS}" ]; then
		rm -rf "${LOCAL_REPO}/${PKGS}"
		echo_blue "Make directory ${LOCAL_REPO}/${PKGS}"
		mkdir -p "${LOCAL_REPO}/${PKGS}"
	fi

	for arch in ${TARGET_ARCH[@]}
	do
		if [ ! -d "${LOCAL_REPO}/${arch}" ]; then
			rm -rf "${LOCAL_REPO}/${arch}"
			echo_blue "Make directory ${LOCAL_REPO}/${arch}"
			mkdir -p "${LOCAL_REPO}/${arch}"
		fi
		if [ ! -f "${LOCAL_REPO}/${arch}/${REPO_NAME}.db.tar.gz" ]; then
			rm -rf "${LOCAL_REPO}/${arch}/${REPO_NAME}.db.tar.gz"
			echo_blue "Make ${LOCAL_REPO}/${arch}/${REPO_NAME}.db.tar.gz"
			tar zcf "${LOCAL_REPO}/${arch}/${REPO_NAME}.db.tar.gz" --files-from /dev/null
		fi
		if [ ! -e "${LOCAL_REPO}/${arch}/${REPO_NAME}.db" ]; then
			rm -rf "${LOCAL_REPO}/${arch}/${REPO_NAME}.db"
			echo_blue "Make ${LOCAL_REPO}/${arch}/${REPO_NAME}.db"
			ln -s "${REPO_NAME}.db.tar.gz" "${LOCAL_REPO}/${arch}/${REPO_NAME}.db"
		fi
		if [ ! -f "${LOCAL_REPO}/${arch}/${REPO_NAME}.files.tar.gz" ]; then
			rm -rf "${LOCAL_REPO}/${arch}/${REPO_NAME}.files.tar.gz"
			echo_blue "Make ${LOCAL_REPO}/${arch}/${REPO_NAME}.files.tar.gz"
			tar zcf "${LOCAL_REPO}/${arch}/${REPO_NAME}.files.tar.gz" --files-from /dev/null
		fi
		if [ ! -e "${LOCAL_REPO}/${arch}/${REPO_NAME}.files" ]; then
			rm -rf "${LOCAL_REPO}/${arch}/${REPO_NAME}.files"
			echo_blue "Make ${LOCAL_REPO}/${arch}/${REPO_NAME}.files"
			ln -s "${REPO_NAME}.files.tar.gz" "${LOCAL_REPO}/${arch}/${REPO_NAME}.files"
		fi
	done

	local lscmd="ls ${LOCAL_REPO} --ignore=pkgs"
	for arch in ${TARGET_ARCH[@]}
	do
		lscmd="${lscmd} --ignore=${arch}"
	done
	for remove in $($lscmd)
	do
		echo_blue "Remove ${LOCAL_REPO}/${remove}"
		rm -rf "${LOCAL_REPO}/${remove}"
	done
}

#Function
function RemovePkgFromRepo {
	local findcmd="find \"${LOCAL_REPO}/${PKGS}\" -mindepth 1 ! \\( ${FINDOPTION} \\)"
	for pkg in $(eval ${findcmd})
	do
		echo_blue "Remove ${pkg}"
		rm -rf "${pkg}"
	done

	local findcmd="find . \\( ${FINDOPTION} \\) -not -path \"./${LOCAL_REPO}/*\" -exec basename \"{}\" \\;"
	local findresult=($(eval ${findcmd}))

	local findcmd="find \"${LOCAL_REPO}/${PKGS}\" -maxdepth 1 \\( ${FINDOPTION} \\) -exec basename \"{}\" \\;"
	for pkg in $(eval ${findcmd})
	do
		if [ -z "$(echo "${findresult[@]}" | grep "${pkg}")" ]; then
			echo_blue "Remove ${LOCAL_REPO}/${PKGS}/${pkg}"
			rm -rf "${LOCAL_REPO}/${PKGS}/${pkg}"
		fi
	done
}

#Function
function RemoveLinkFromRepo {
	for arch in ${TARGET_ARCH[@]}
	do
		pushd . &> /dev/null
		cd "${LOCAL_REPO}/${arch}"
		local findcmd="find . ${FINDOPTION}"
		for pkg in $(eval ${findcmd})
		do
			if [ -L "${pkg}" ]; then
				if [ ! -e "$(readlink ${pkg})" ]; then
					echo_blue "Remove ${pkg}"
					rm -rf "${pkg}"
				fi
			else
				echo_blue "Remove ${pkg}"
				rm -rf "${pkg}"
			fi
		done
		popd &> /dev/null
	done
}

#Function
function RemovePkgFromDb {
	for arch in ${TARGET_ARCH[@]}
	do
		pushd . &> /dev/null
		cd "${LOCAL_REPO}/${arch}"
		local dbcmd="zcat \"${REPO_NAME}.db.tar.gz\"  | grep -a \".*-any\.pkg\.tar\..*\|.*-${arch}\.pkg\.tar\..*\""
		local dblist=($(eval ${dbcmd}))
		local filescmd="zcat \"${REPO_NAME}.files.tar.gz\"  | grep -a \".*-any\.pkg\.tar\..*\|.*-${arch}\.pkg\.tar\..*\""
		local fileslist=($(eval ${filescmd}))
		local findcmd="find . \\( ${FINDOPTION} \\) -exec basename \"{}\" \\;"
		local pkglist=($(eval ${findcmd}))
		for pkg in ${dblist[@]}
		do
			if [ -z "$(echo "${pkglist[@]}" | grep "${pkg}")" ]; then
				local pkgname="$(echo "${pkg}" | sed 's/^\(.*\)-\(.*\)-\(.*\)-\(.*\)\.pkg\.tar\..*$/\1/g')"
				repo-remove ${REPO_NAME}.db.tar.gz ${pkgname}
			fi
		done
		for pkg in ${fileslist[@]}
		do
			if [ -z "$(echo "${pkglist[@]}" | grep "${pkg}")" ]; then
				local pkgname="$(echo "${pkg}" | sed 's/^\(.*\)-\(.*\)-\(.*\)-\(.*\)\.pkg\.tar\..*$/\1/g')"
				repo-remove ${REPO_NAME}.files.tar.gz ${pkgname}
			fi
		done
		popd &> /dev/null
	done
}

#Function
function AddPkgToRepo {
	local findcmd="find . \\( ${FINDOPTION} \\) -not -path \"./${LOCAL_REPO}/*\""
	for pkg in $(eval ${findcmd})
	do
		local file="$(basename "${pkg}")"
		if [ ! -e "${LOCAL_REPO}/${PKGS}/${file}" ]; then
			echo_blue "Copy ${pkg}"
			cp -a "${pkg}" "${LOCAL_REPO}/${PKGS}/${file}"
		fi
	done
}

#Function
function AddLinkToRepo {
	local findcmd="find \"${LOCAL_REPO}/${PKGS}\" ${FINDOPTION}"
	for pkg in $(eval ${findcmd})
	do
		local pkgfile="$(basename "${pkg}")" 
		local pkgarch="$(echo "${pkgfile}" | sed 's/^\(.*\)-\(.*\)-\(.*\)-\(.*\)\.pkg\.tar\..*$/\4/g')"
		if [ "${pkgarch}" = "any" ]; then
			for arch in ${TARGET_ARCH[@]}
			do
				if [ ! -e "${LOCAL_REPO}/${arch}/${pkgfile}" ]; then
					echo_blue "Link ${LOCAL_REPO}/${arch}/${pkgfile}"
					ln -sf "../${PKGS}/${pkgfile}" "${LOCAL_REPO}/${arch}/${pkgfile}"
				fi
			done
		elif [ -d "${LOCAL_REPO}/${pkgarch}" ]; then
			if [ ! -e "${LOCAL_REPO}/${pkgarch}/${pkgfile}" ]; then
				echo_blue "Link ${LOCAL_REPO}/${pkgarch}/${pkgfile}"
				ln -sf "../${PKGS}/${pkgfile}" "${LOCAL_REPO}/${pkgarch}/${pkgfile}"
			fi
		fi
	done
}

#Function
function AddPkgToDb {
	for arch in ${TARGET_ARCH[@]}
	do
		pushd . &> /dev/null
		cd "${LOCAL_REPO}/${arch}"
		local dbcmd="zcat \"${REPO_NAME}.db.tar.gz\"  | grep -a \".*-any\.pkg\.tar\..*\|.*-${arch}\.pkg\.tar\..*\""
		local dblist=($(eval ${dbcmd}))
		local filescmd="zcat \"${REPO_NAME}.files.tar.gz\"  | grep -a \".*-any\.pkg\.tar\..*\|.*-${arch}\.pkg\.tar\..*\""
		local fileslist=($(eval ${filescmd}))
		local findcmd="find . \\( ${FINDOPTION} \\) -exec basename \"{}\" \\;"
		local pkglist=($(eval ${findcmd}))
		for pkg in ${pkglist[@]}
		do
			if [ -z "$(echo "${dblist[@]}" | grep "${pkg}")" ]; then
				repo-add -n ${REPO_NAME}.db.tar.gz ${pkg}
			fi
			if [ -z "$(echo "${fileslist[@]}" | grep "${pkg}")" ]; then
				repo-add -n -f ${REPO_NAME}.files.tar.gz ${pkg}
			fi
		done
		popd &> /dev/null
	done
}

#Function
function ClearRepo {
	for arch in ${TARGET_ARCH[@]}
	do
		rm -rf "${LOCAL_REPO}/${arch}/${REPO_NAME}.db.tar.gz.old"
		rm -rf "${LOCAL_REPO}/${arch}/${REPO_NAME}.files.tar.gz.old"
	done
}



#Main
echo_green "Generate repository"
GenerateRepo
echo

echo_green "Remove pkg from repository"
RemovePkgFromRepo
echo

echo_green "Remove link from repository"
RemoveLinkFromRepo
echo

echo_green "Remove pkg from DB"
RemovePkgFromDb
echo

echo_green "Add package to repository"
AddPkgToRepo
echo

echo_green "Add link to repository"
AddLinkToRepo
echo

echo_green "Add pkg to db"
AddPkgToDb
echo

echo_green "Clear repository"
ClearRepo
echo

exit 0

