#!/bin/bash

# script location
export SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
export SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
export SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
export SCRIPT_PARENT=$(dirname "${SCRIPT_DIR}")

# formatting
export ESC=$(printf "\e")
export BOLD="${ESC}[1m"
export RESET="${ESC}[0m"
export RED="${ESC}[31m"
export GREEN="${ESC}[32m"
export BLUE="${ESC}[34m"
export UNDERLINE="${ESC}[4m"
export CYAN="\e[36m"

# IMPORTS
source "${SCRIPT_DIR}/lib/readFileToMap.sh"

function selectPathToRepos() {
	# Sets:
	# - PATH_TO_REPOS
	
	local _REQUIRED=(
		REPO_PATHS_ARRAY
	)
	local _PATH=""
    
	# check required vars
    for var in "${_REQUIRED[@]}"  ; do
        if [[ -z "${!var}" ]]; then
            echo "Error: ${var} is not set or is empty." >&2
			return 1
        fi
    done

	if [[ ${#REPO_PATHS_ARRAY[@]} -eq 0 ]]; then
		echo "No repository paths given!"
		return 1
	fi

	# select
	echo "---"
	echo -e "${BOLD}"Select path to repositories"${RESET}"
	select _PATH in "${REPO_PATHS_ARRAY[@]}"; do
		if [[ -z "${_PATH}" ]]; then
			echo "Invalid selection, please try again."
			continue
		fi

		PATH_TO_REPOS="${_PATH}"

		return 0
	done
}

function selectBorgRepo() {
	# Sets:
	# - BORG_REPO
	# - REPO_NAME

	local _ARRAY_OF_REPOS=()
	local _REPO # for select
	local _REQUIRED=(
		PATH_TO_REPOS
	)
    
	# check required vars
    for var in "${_REQUIRED[@]}"  ; do
        if [[ -z "${!var}" ]]; then
            echo "Error: ${var} is not set or is empty." >&2
			return 1
        fi
    done

	# set _ARRAY_OF_REPOS
	## only repos owned by current user are returned

	echo "---"
	echo "Searching for repos in ${PATH_TO_REPOS} ..."
	#find $PATH_TO_REPOS -maxdepth 1 -mindepth 1 -type d -user $USER -print0 -exec basename {} \; |
	#  while IFS= read -r -d '' item; do
	#    _ARRAY_OF_REPOS+=($item)
	#  done

	mapfile -t _ARRAY_OF_REPOS < <(find ${PATH_TO_REPOS} -maxdepth 1 -mindepth 1 -type d -user ${USER} -exec basename {} \;) # find /media/frida/borg_backup -maxdepth 1 -mindepth 1 -type d -exec basename {} \;
	echo "Number of repos  for ${USER}: ${#_ARRAY_OF_REPOS[@]}"
	echo "---"

	# check
	if [[ ${#_ARRAY_OF_REPOS[@]} -eq 0 ]]; then
		echo "Error: _ARRAY_OF_REPOS is empty."
		return 1
	fi

	# select
	echo -e "${BOLD}Select repository in ${GREEN}${PATH_TO_REPOS}${RESET}"
	select _REPO in "${_ARRAY_OF_REPOS[@]}"; do

		if [[ -z "${_REPO}" ]]; then
			echo "Invalid selection, please try again."
			continue
		fi

		BORG_REPO="${PATH_TO_REPOS}/${_REPO}"
		REPO_NAME="${_REPO}"

		break
	done

	function handleOptionStrato() {
		#export BORG_REPO='${PATH_REPOS}/le-guin.home'
		#export BORG_PASSPHRASE='jy1UvLDEaYcAHD16UOJgnZoz1Lyn0Y'
		echo "Calling remote backup script '/home/borg/un.borg.backup.strato.sh' ..."
		ssh -tp 151 unonweb@strato "sudo --user borg /home/borg/un.borg.backup.strato.sh"
		EXIT_CODE_BACKUP=$?
		exit $EXIT_CODE_BACKUP
	}

}

function selectBorgArchive {
	# Sets: 
	# - ARCHIVE_NAME
	# Needs:
	# - BORG_REPO
	local _REQUIRED=(
		BORG_REPO
	)
	local _ARCHIVES
	local _ARCHIVES_ARRAY=()
	local _item

	# check required
    for var in "${_REQUIRED[@]}"  ; do
        if [[ -z "${!var}" ]]; then
            echo "Error: ${var} is not set or is empty." >&2
			return 1
        fi
    done

	# Show available archives in the chosen repository
	echo "Checking archives at ${GREEN}${BORG_REPO}${RESET} ..."
	_ARCHIVES=$(borg list "${BORG_REPO}" 2>/dev/null | awk '{print $1}')

	if [ -z "${_ARCHIVES}" ]; then
		echo "No archives found in repository ${BORG_REPO}"
	else
		# Prompt the user to choose an archive
		echo "${BOLD}Available archives:"
		_ARCHIVES_ARRAY=($_ARCHIVES)
		
		select _item in "${_ARCHIVES_ARRAY[@]}"; do
			if [ -n "${_item}" ]; then
				echo "Archive selected: ${_item}"
				ARCHIVE_NAME="${_item}"
				break # return
			else
				echo "Invalid selection. Please choose a valid archive."
			fi
		done
	fi
}

function borgBackup {
    
	local _REQUIRED=(
		REPO_NAME
		BORG_REPO
		PATH_BACKUP_SCRIPTS
	)
    
	# check required vars
    for var in "${_REQUIRED[@]}"  ; do
        if [[ -z "${!var}" ]]; then
            echo "Error: ${var} is not set or is empty." >&2
			return 1
        fi
    done
    
    # automatically select backup script
    case ${REPO_NAME} in
        *.system)
            BACKUP_SCRIPT="${PATH_BACKUP_SCRIPTS}/borg.backup.system.sh"
            ;;
        *.home.*)
            BACKUP_SCRIPT="${PATH_BACKUP_SCRIPTS}/borg.backup.home.sh"
            ;;
        common)
            BACKUP_SCRIPT="${PATH_BACKUP_SCRIPTS}/borg.backup.common.sh"
            ;;  
        machines*)
            BACKUP_SCRIPT="${PATH_BACKUP_SCRIPTS}/borg.backup.machines.sh"
            ;;
    esac

	if [[ -z ${BACKUP_SCRIPT} ]]; then
		echo "No matching template script found."
		echo "Please select:"
		selectBackupScript
	else
		echo "Run ${GREEN}${BACKUP_SCRIPT}${RESET}? (y|n)"
		read -p ">> " -n 1
		if [[ ${REPLY} == "n" ]]; then
			selectBackupScript
		fi
	fi
	
    # check
    if [[ ! -f ${BACKUP_SCRIPT} ]]; then
        echo "Error: BACKUP_SCRIPT not available: ${BACKUP_SCRIPT}"
        exit 1
    fi

    # check repo
    if [[ -z ${BORG_REPO} ]]; then
        echo "Error: BORG_REPO is empty."
        exit 1
    fi

    # feedback
	if [[ ! -d ${BORG_REPO} && ! -w ${BORG_REPO} ]]; then
        echo "ERROR: Repo does not exist or is not writable by ${USER}"
        exit 1
    fi

    # print fs capacity
	echo
    df --human-readable --print-type "${BORG_REPO}"
    echo
    
    # get user confirmation
    while true; do
        echo "Hit enter to proceed!"
        read -n 1 -p ">> "
        echo ""
        if [[ -z ${REPLY} ]]; then
            break
        fi
    done

    # perform backup
    ${BACKUP_SCRIPT}
}

function selectBackupScript {
	# Sets
	# - BACKUP_SCRIPT

	local _REQUIRED=(
		PATH_BACKUP_SCRIPTS
	)
	local _SCRIPTS=()
    
	# check required vars
    for var in "${_REQUIRED[@]}"  ; do
        if [[ -z "${!var}" ]]; then
            echo "Error: ${var} is not set or empty." >&2
			return 1
        fi
    done

	echo
	echo -e "${BOLD}Available scipts:${RESET}"
	_SCRIPTS=( "${PATH_BACKUP_SCRIPTS}"/borg.backup.*)
	select filename in "${_SCRIPTS[@]##*/}"; do
		if [[ -z "${filename}" ]]; 
			then echo "ERROR: invalid option. Try again."
		else
			BACKUP_SCRIPT="${PATH_BACKUP_SCRIPTS}/${filename}"
			echo
			echo -e "Script path: ${GREEN}${BACKUP_SCRIPT}${RESET}"
			break
		fi
	done
}

function borgPrune {

	local _REQUIRED=(
		BORG_REPO
	)

	local _KEEP_DAILY=7
	local _KEEP_WEEKLY=4
	local _KEEP_MONTHLY=1
    
	# check required vars
    for var in "${_REQUIRED[@]}"; do
        if [[ -z "${!var}" ]]; then
            echo "Error: ${var} is not set or empty."
			return 1
        fi
    done

	echo "---"
	echo -e "--keep-daily ${GREEN}${_KEEP_DAILY}${RESET}"
	echo -e "--keep-weekly ${GREEN}${_KEEP_WEEKLY}${RESET}"
	echo -e "--keep-monthly ${GREEN}${_KEEP_MONTHLY}${RESET}"
	
	# change defaults
	echo -e "${BOLD}Change these defaults?${RESET} (y|n)"
	read -p ">> "
	
	if [[ ${REPLY} == "y" ]]; then
		echo -n "--keep-daily "; read _KEEP_DAILY
		echo -n "--keep-weekly "; read _KEEP_WEEKLY
		echo -n "--keep-monthly "; read _KEEP_MONTHLY
	fi
	
	# prune
	echo -e "${BOLD}Pruning repository ${GREEN}${BORG_REPO}${RESET} ..."
	borg prune \
		--list \
		--show-rc \
		--keep-daily ${_KEEP_DAILY} \
		--keep-weekly ${_KEEP_WEEKLY} \
		--keep-monthly ${_KEEP_MONTHLY} \
		"${BORG_REPO}"
	
	# --glob-archives '{hostname}-*' \
}

function main {
    # globals static
    MOUNT_POINT="/tmp/mount_borg"
	PATH_BACKUP_SCRIPTS="${SCRIPT_DIR}/run"
	PATH_CONFIG="${SCRIPT_PARENT}/config.cfg"
	
    # globals dynamic
	declare -A CONFIG
    BORG_REPO="" # path of selected repo
    REPO_NAME="" # name of selected repo
    PATH_TO_REPOS="" # path to all repos
	REPO_PATHS_ARRAY=()
    ARCHIVE_NAME=""
	BACKUP_SCRIPT=""

    # local
	local _OPTIONS_1=(
		"Init new repo"
		"Select existing repo"
	)
    local _OPTIONS_2=(
        "Backup"
        "List archives"
        "Prune"
        "Compact"
        "Mount"
		"Delete"
		"Info"
		"Change repo"
    )

	# CONFIG
	readFileToMap CONFIG ${PATH_CONFIG}
    REPO_PATHS_ARRAY=(${CONFIG[REPO_PATHS]})

	# MENU 1
	select opt in "${_OPTIONS_1[@]}"; do
		if [[ -z "${opt}" ]]; then echo "ERROR: invalid option. Try again."
		else break; fi
	done

	case ${opt} in

		"Init new repo")

			# set PATH_TO_REPOS
			selectPathToRepos
			# set REPO_NAME
			echo "Enter name for new repo at ${GREEN}${PATH_TO_REPOS}${RESET}"
			read -p ">> " REPO_NAME
			
			BORG_REPO="${PATH_TO_REPOS}/${REPO_NAME}"

			# check
			if [[ ! -w ${PATH_TO_REPOS} ]]; then
				echo "ERROR: ${PATH_TO_REPOS} is not writable by ${USER}"
				exit 1
			fi
			
			# confirm
			echo -e "Init new repo at ${GREEN}${BORG_REPO}${RESET}? (y|n)"
			read -n 1 -p ">> "
			echo ""
			if [[ ${REPLY} == "y" ]]; then
				# init repo
				borg init --encryption=repokey ${BORG_REPO} # init local repo
			else
				echo "Aborted by user."
			fi
			;;

		"Select existing repo")

			# set PATH_TO_REPOS
			selectPathToRepos
			# set BORG_REPO
			# set REPO_NAME
			selectBorgRepo
			# set passphrase
			#echo -e "${BOLD}Enter passphrase for ${GREEN}${BORG_REPO}${RESET}"
			#read -sp ">> " BORG_PASSPHRASE
			#echo
			;;
	esac

    export BORG_REPO
    export BORG_PASSPHRASE

    # now we have a repository
    # interactive loop
    while true; do
        # header
        echo "---"
		echo -e "${BOLD}What do you want to do with ${GREEN}${REPO_NAME}${RESET}?"
        # select
        select opt in "${_OPTIONS_2[@]}"; do
            if [[ -z "${opt}" ]]; then
                echo "ERROR: invalid option. Try again."
            else
                break
            fi
        done

        case ${opt} in

        "Backup")

            borgBackup
            ;;

        "List archives")

            echo -e "Listing archives in ${BORG_REPO} ..."
			echo -en "${GREEN}"
            borg list ${BORG_REPO}
			echo -en "${RESET}"
            ;;

        "Prune")

			borgPrune
            ;;

        "Compact")

            # actually free repo disk space by compacting segments
            echo -e "${BOLD}Compacting ${GREEN}${BORG_REPO}${RESET} ..."
            borg compact "${BORG_REPO}"
            ;;

        "Mount")

            selectBorgArchive
			export ARCHIVE_NAME BORG_REPO MOUNT_POINT \
			"${SCRIPT_DIR}/run/borg.mount-archive.sh"
            ;;
		
		"Delete")

			#selectBorgArchive
			echo -e "${BOLD}Enter archive to delete${RESET}"
			read -p ">> "
			if [[ -n ${REPLY} ]]; then
				ARCHIVE_NAME=${REPLY}
				borg delete --list --stats --progress ${BORG_REPO}::${ARCHIVE_NAME}
				echo "When deleting archives, repository disk space is not freed until you run borg compact."
			else
				echo "Error: Empty REPLY"
			fi
			;;

		"Change repo")

			selectBorgRepo
			;;

		"Info")

			echo "---"
			borg info "${BORG_REPO}"
			;;

        *)

            echo "Invalid selection: ${opt}"
            sleep 1
            ;;

        esac
    done
}

main
