function borgMountArchive {
    
	local _MOUNT_CMD
	local _REQUIRED=(
		BORG_REPO
		ARCHIVE_NAME
		MOUNT_POINT
	)
    
	# check required vars
    for var in "${_REQUIRED[@]}"  ; do
        if [[ -z "${!var}" ]]; then
            echo "Error: ${var} is not set or is empty." >&2
			return 1
        fi
    done

    # Create mount point if it doesn't exist
    if [ ! -d "${MOUNT_POINT}" ]; then
        echo -e "Creating mountpoint: ${GREEN}${MOUNT_POINT}${RESET}"
        mkdir -p "${MOUNT_POINT}"
    fi

    # Mount the chosen archive
    _MOUNT_CMD="borg mount ${BORG_REPO}::${ARCHIVE_NAME} ${MOUNT_POINT} -o allow_other"
    echo "Mounting archive with cmd:"
    echo -e "${GREEN}${_MOUNT_CMD}${RESET}"
    ${_MOUNT_CMD}

    if [ ${?} -eq 0 ]; then
        echo "Archive mounted successfully at ${MOUNT_POINT}"
        echo "Open with:"
        echo "nautilus ${MOUNT_POINT} &"
        echo "Unmount with:"
        echo "umount ${MOUNT_POINT}"
    else
        echo "Error: Failed to mount the archive."
    fi
}

borgMountArchive ${@}