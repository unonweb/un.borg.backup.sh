function borgBackupSystem {

	local _PATH_BACKUP="/etc /root /var /opt"

	if [[ -z ${BORG_REPO} ]]; then
		echo "BORG_REPO is empty: ${BORG_REPO}"
		exit 1
	fi

	echo "Starting to backup ${_PATH_BACKUP}"

	sudo --set-home --preserve-env borg create ${BORG_REPO}::'{hostname}-{now}' "${_PATH_BACKUP}" \
		--progress \
		--verbose \
		--filter AME \
		--list \
		--stats \
		--lock-wait 600 \
		--compression lz4 \
		--exclude-caches \
		--exclude 'var/tmp' \
		--exclude 'var/run' \
		--exclude 'var/cache' \
		--exclude 'var/lock'
	#2>> borg.log
	#2> >(tee borg.log >&2)

	EXIT_CODE_BACKUP=${?}
}

borgBackupSystem ${@}