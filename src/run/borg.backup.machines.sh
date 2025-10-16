function borgBackupMachines {
	# requires 
	# - BORG_REPO

	local _PATH_BACKUP
	local _REPO_NAME

	if [[ -z ${BORG_REPO} ]]; then
		echo "BORG_REPO is empty: ${BORG_REPO}"
		exit 1
	fi

	_REPO_NAME=${BORG_REPO##*/} # /media/frida/borg_backup/machines.ghost-ub --> machines.ghost-ub
	_REPO_NAME=${_REPO_NAME//./\/} # machines.ghost-ub --> machines/ghost-ub
	_PATH_BACKUP="/var/lib/${_REPO_NAME}" # --> /var/lib/machines/ghost-ub

	if ! sudo test -e "${_PATH_BACKUP}"; then
		echo "[borgBackupMachines] ERROR: Path does not exist: ${_PATH_BACKUP}"
		return 1
	fi
	
	echo "Starting to backup ${_PATH_BACKUP}"

	borg create "${BORG_REPO}"::'{hostname}-{now}' ${_PATH_BACKUP} \
		--progress \
		--verbose \
		--filter AME \
		--list \
		--stats \
		--lock-wait 600 \
		--compression lz4 \
		--exclude-caches \
		--exclude '.Trash-1000' \
		--exclude "${_PATH_BACKUP}/dev" \
		--exclude "${_PATH_BACKUP}/mnt" \
		--exclude "${_PATH_BACKUP}/proc" \
		--exclude "${_PATH_BACKUP}/run" \
		--exclude "${_PATH_BACKUP}/sys" \
		--exclude "${_PATH_BACKUP}/tmp" \
		--exclude "${_PATH_BACKUP}/var/tmp" \
		--exclude "${_PATH_BACKUP}/var/run" \
		--exclude "${_PATH_BACKUP}/var/cache" \
		--exclude "${_PATH_BACKUP}/var/lock"
		

	EXIT_CODE_BACKUP=${?}
}

borgBackupMachines ${@}