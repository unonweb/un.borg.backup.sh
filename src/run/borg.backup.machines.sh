function borgBackupMachines {
	# requires BORG_REPO to be set
	local _PATH_BACKUP="/var/lib/machines"

	if [[ -z ${BORG_REPO} ]]; then
		echo "BORG_REPO is empty: ${BORG_REPO}"
		exit 1
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
		--exclude '.Trash-1000'

	EXIT_CODE_BACKUP=${?}
}

borgBackupMachines ${@}