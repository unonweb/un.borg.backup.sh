function borgBackupHome {
	# Requires:
	# - BORG_REPO

	local _PATH_BACKUP="/home/${USER}"

	local _REQUIRED=(
		BORG_REPO
	)
    
	# check required vars
    for var in "${_REQUIRED[@]}"  ; do
        if [[ -z "${!var}" ]]; then
            echo "Error: ${var} is not set or empty." >&2
			return 1
        fi
    done

	echo "Starting to backup ${GREEN}${_PATH_BACKUP}${RESET} ..."

	borg create "${BORG_REPO}"::'{hostname}-{now}' ${_PATH_BACKUP} \
		--progress \
		--verbose \
		--filter AME \
		--list \
		--stats \
		--lock-wait 600 \
		--compression lz4 \
		--exclude-caches \
		--exclude "${_PATH_BACKUP}/.cache" \
		--exclude "${_PATH_BACKUP}/.npm/_logs" \
		--exclude "${_PATH_BACKUP}/.npm/_cacache" \
		--exclude "${_PATH_BACKUP}/.config/Code/Cache" \
		--exclude "${_PATH_BACKUP}/.config/Code/CachedData" \
		--exclude "${_PATH_BACKUP}/.config/Code/Service Worker/ScriptCache" \
		--exclude "${_PATH_BACKUP}/.config/Code/User/History" \
		--exclude "${_PATH_BACKUP}/.config/libreoffice/*/cache" \
		--exclude "${_PATH_BACKUP}/.local/share/Trash" \

	#2>> ${SCRIPT_NAME}.log
	EXIT_CODE_BACKUP=$?
}

borgBackupHome ${@}