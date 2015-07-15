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


#Validation
if [ -z "$(which repo-add 2> /dev/null)" ]; then
	echo_red "command not found : repo-add"
	exit 1
fi

if [ -x "$(dirname "${0}")/stonecold-repo-check.sh" ]; then
	"$(dirname "${0}")/stonecold-repo-check.sh"
	if [ "${?}" != "0" ]; then
		exit 1
	fi
fi


#Function
fn_generate_repo() {
	if [ ! -d "${LOCAL_REPO}" ]; then
		rm -rf "${LOCAL_REPO}"
		echo_blue " -> " "Make directory - ${LOCAL_REPO}"
		mkdir -p "${LOCAL_REPO}"
	fi

	if [ ! -d "${LOCAL_REPO}/${PKGDIR}" ]; then
		rm -rf "${LOCAL_REPO}/${PKGDIR}"
		echo_blue " -> " "Make directory ${LOCAL_REPO}/${PKGDIR}"
		mkdir -p "${LOCAL_REPO}/${PKGDIR}"
	fi

	local arch=
	for arch in ${TARGET_ARCH[@]}
	do
		if [ ! -d "${LOCAL_REPO}/${arch}" ]; then
			rm -rf "${LOCAL_REPO}/${arch}"
			echo_blue " -> " "Make directory ${LOCAL_REPO}/${arch}"
			mkdir -p "${LOCAL_REPO}/${arch}"
		fi
		if [ ! -f "${LOCAL_REPO}/${arch}/${REPO_NAME}.db.tar.gz" ]; then
			rm -rf "${LOCAL_REPO}/${arch}/${REPO_NAME}.db.tar.gz"
			echo_blue " -> " "Make ${LOCAL_REPO}/${arch}/${REPO_NAME}.db.tar.gz"
			tar zcf "${LOCAL_REPO}/${arch}/${REPO_NAME}.db.tar.gz" --files-from /dev/null
		fi
		if [ ! -e "${LOCAL_REPO}/${arch}/${REPO_NAME}.db" ]; then
			rm -rf "${LOCAL_REPO}/${arch}/${REPO_NAME}.db"
			echo_blue " -> " "Make ${LOCAL_REPO}/${arch}/${REPO_NAME}.db"
			ln -s "${REPO_NAME}.db.tar.gz" "${LOCAL_REPO}/${arch}/${REPO_NAME}.db"
		fi
		if [ ! -f "${LOCAL_REPO}/${arch}/${REPO_NAME}.files.tar.gz" ]; then
			rm -rf "${LOCAL_REPO}/${arch}/${REPO_NAME}.files.tar.gz"
			echo_blue " -> " "Make ${LOCAL_REPO}/${arch}/${REPO_NAME}.files.tar.gz"
			tar zcf "${LOCAL_REPO}/${arch}/${REPO_NAME}.files.tar.gz" --files-from /dev/null
		fi
		if [ ! -e "${LOCAL_REPO}/${arch}/${REPO_NAME}.files" ]; then
			rm -rf "${LOCAL_REPO}/${arch}/${REPO_NAME}.files"
			echo_blue " -> " "Make ${LOCAL_REPO}/${arch}/${REPO_NAME}.files"
			ln -s "${REPO_NAME}.files.tar.gz" "${LOCAL_REPO}/${arch}/${REPO_NAME}.files"
		fi
	done

	local lscmd="ls ${LOCAL_REPO} --ignore=pkgs"
	local arch=
	for arch in ${TARGET_ARCH[@]}
	do
		lscmd="${lscmd} --ignore=${arch}"
	done
	local remove=
	for remove in $($lscmd)
	do
		echo_blue " -> " "Remove ${LOCAL_REPO}/${remove}"
		rm -rf "${LOCAL_REPO}/${remove}"
	done
}

#Function
fn_remove_pkg_from_repo() {
	local findcmd="find \"${LOCAL_REPO}/${PKGDIR}\" -mindepth 1 ! \\( ${FIND_OPTION} \\)"
	local pkg=
	for pkg in $(eval ${findcmd})
	do
		echo_blue " -> " "Remove ${pkg}"
		rm -rf "${pkg}"
	done

	local findcmd="find . \\( ${FIND_OPTION} \\) -not -path \"./${LOCAL_REPO}/*\" -exec basename \"{}\" \\;"
	local findresult=($(eval ${findcmd}))

	local findcmd="find \"${LOCAL_REPO}/${PKGDIR}\" -maxdepth 1 \\( ${FIND_OPTION} \\) -exec basename \"{}\" \\;"
	local pkg=
	for pkg in $(eval ${findcmd})
	do
		if [ -z "$(echo "${findresult[@]}" | grep "${pkg}")" ]; then
			echo_blue " -> " "Remove ${LOCAL_REPO}/${PKGDIR}/${pkg}"
			rm -rf "${LOCAL_REPO}/${PKGDIR}/${pkg}"
		fi
	done
}

#Function
fn_remove_link_from_repo() {
	local arch=
	for arch in ${TARGET_ARCH[@]}
	do
		pushd . &> /dev/null
		cd "${LOCAL_REPO}/${arch}"
		local findcmd="find . ${FIND_OPTION}"
		local pkg=
		for pkg in $(eval ${findcmd})
		do
			if [ -L "${pkg}" ]; then
				if [ ! -e "$(readlink ${pkg})" ]; then
					echo_blue " ->" "Remove ${pkg}"
					rm -rf "${pkg}"
				fi
			else
				echo_blue " -> " "Remove ${pkg}"
				rm -rf "${pkg}"
			fi
		done
		popd &> /dev/null
	done
}

#Function
fn_remove_pkg_from_db() {
	local arch=
	for arch in ${TARGET_ARCH[@]}
	do
		pushd . &> /dev/null
		cd "${LOCAL_REPO}/${arch}"
		local dbcmd="zcat \"${REPO_NAME}.db.tar.gz\"  | grep -a \".*-any\.pkg\.tar\..*\|.*-${arch}\.pkg\.tar\..*\""
		local dblist=($(eval ${dbcmd}))
		local filescmd="zcat \"${REPO_NAME}.files.tar.gz\"  | grep -a \".*-any\.pkg\.tar\..*\|.*-${arch}\.pkg\.tar\..*\""
		local fileslist=($(eval ${filescmd}))
		local findcmd="find . \\( ${FIND_OPTION} \\) -exec basename \"{}\" \\;"
		local pkglist=($(eval ${findcmd}))
		local pkg=
		for pkg in ${dblist[@]}
		do
			if [ -z "$(echo "${pkglist[@]}" | grep "${pkg}")" ]; then
				local pkgname="$(echo "${pkg}" | sed 's/^\(.*\)-\(.*\)-\(.*\)-\(.*\)\.pkg\.tar\..*$/\1/g')"
				repo-remove ${REPO_NAME}.db.tar.gz ${pkgname}
			fi
		done
		local pkg=
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
fn_add_pkg_to_repo() {
	local findcmd="find . \\( ${FIND_OPTION} \\) -not -path \"./${LOCAL_REPO}/*\""
	local pkg=
	for pkg in $(eval ${findcmd})
	do
		local file="$(basename "${pkg}")"
		if [ ! -e "${LOCAL_REPO}/${PKGDIR}/${file}" ]; then
			echo_blue " -> " "Copy ${pkg}"
			cp -a "${pkg}" "${LOCAL_REPO}/${PKGDIR}/${file}"
		fi
	done
}

#Function
fn_add_link_to_repo() {
	local findcmd="find \"${LOCAL_REPO}/${PKGDIR}\" ${FIND_OPTION}"
	local pkg=
	for pkg in $(eval ${findcmd})
	do
		local pkgfile="$(basename "${pkg}")" 
		local pkgarch="$(echo "${pkgfile}" | sed 's/^\(.*\)-\(.*\)-\(.*\)-\(.*\)\.pkg\.tar\..*$/\4/g')"
		if [ "${pkgarch}" = "any" ]; then
			local arch=
			for arch in ${TARGET_ARCH[@]}
			do
				if [ ! -e "${LOCAL_REPO}/${arch}/${pkgfile}" ]; then
					echo_blue " -> " "Link ${LOCAL_REPO}/${arch}/${pkgfile}"
					ln -sf "../${PKGDIR}/${pkgfile}" "${LOCAL_REPO}/${arch}/${pkgfile}"
				fi
			done
		elif [ -d "${LOCAL_REPO}/${pkgarch}" ]; then
			if [ ! -e "${LOCAL_REPO}/${pkgarch}/${pkgfile}" ]; then
				echo_blue " -> " "Link ${LOCAL_REPO}/${pkgarch}/${pkgfile}"
				ln -sf "../${PKGDIR}/${pkgfile}" "${LOCAL_REPO}/${pkgarch}/${pkgfile}"
			fi
		fi
	done
}

#Function
fn_add_pkg_to_db() {
	local arch=
	for arch in ${TARGET_ARCH[@]}
	do
		pushd . &> /dev/null
		cd "${LOCAL_REPO}/${arch}"
		local dbcmd="zcat \"${REPO_NAME}.db.tar.gz\"  | grep -a \".*-any\.pkg\.tar\..*\|.*-${arch}\.pkg\.tar\..*\""
		local dblist=($(eval ${dbcmd}))
		local filescmd="zcat \"${REPO_NAME}.files.tar.gz\"  | grep -a \".*-any\.pkg\.tar\..*\|.*-${arch}\.pkg\.tar\..*\""
		local fileslist=($(eval ${filescmd}))
		local findcmd="find . \\( ${FIND_OPTION} \\) -exec basename \"{}\" \\;"
		local pkglist=($(eval ${findcmd}))
		local pkg=
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
fn_clear_repo() {
	local arch=
	for arch in ${TARGET_ARCH[@]}
	do
		rm -rf "${LOCAL_REPO}/${arch}/${REPO_NAME}.db.tar.gz.old"
		rm -rf "${LOCAL_REPO}/${arch}/${REPO_NAME}.files.tar.gz.old"
	done
}


#Main
REPO_NAME="StoneCold"
LOCAL_REPO="stonecold-repo"
TARGET_ARCH=("i686" "x86_64" "arm" "armv6h" "armv7h")
PKGDIR="pkgs"
FIND_OPTION="-name \"*-any.pkg.tar.*\""
for arch in ${TARGET_ARCH[@]}
do
	FIND_OPTION="${FIND_OPTION} -o -name \"*-${arch}.pkg.tar.*\""
done

echo_green "==> " "Start - Generating repository..."
fn_generate_repo
echo_green "==> " "Done."
echo

echo_green "==> " "Start - Remove package from repository..."
fn_remove_pkg_from_repo
echo_green "==> " "Done."
echo

echo_green "==> " "Start - Remove link from repository..."
fn_remove_link_from_repo
echo_green "==> " "Done."
echo

echo_green "==> " "Start - Remove package from DB..."
fn_remove_pkg_from_db
echo_green "==> " "Done."
echo

echo_green "==> " "Start - Add package to repository"
fn_add_pkg_to_repo
echo_green "==> " "Done."
echo

echo_green "==> " "Start - Add link to repository"
fn_add_link_to_repo
echo_green "==> " "Done."
echo

echo_green "==> " "Start - Add package to DB"
fn_add_pkg_to_db
echo_green "==> " "Done."
echo

echo_green "==> " "Start - Clear repository"
fn_clear_repo
echo_green "==> " "Done."
echo

exit 0

