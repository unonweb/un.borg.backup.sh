#!/bin/bash

# script location
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
# formatting
ESC=$(printf "\e")
BOLD="${ESC}[1m"
RESET="${ESC}[0m"
RED="${ESC}[31m"
GREEN="${ESC}[32m"
BLUE="${ESC}[34m"
UNDERLINE="${ESC}[4m"

# IMPORTS
source "${SCRIPT_DIR}/lib/readFileToArray.sh"

# static
declare -r MOUNT_POINT="/tmp/mount_borg"
declare -A FILES=(
  [repoPaths]="${SCRIPT_DIR}/borg_repo_paths.txt"
)

function info() {
  # produces a message like
  # Mon Oct  7 21:45:27 UTC 2024 Pruning repository
  printf "\n%s %s\n\n" "$(date)" "$*" >&2
}

function selectPathToRepos() {
  local -n _result=$1
  local -n _repoPaths=$2 # array
  local _path=""

  if [[ ${#_repoPaths[@]} -eq 0 ]]; then
    echo "No repository paths given!"
    return 1
  fi

  echo "---"
  echo -e "${BOLD}"Select path to repositories"${RESET}"
  select _path in "${_repoPaths[@]}"; do
    if [[ -z "$_path" ]]; then
      echo "Invalid selection, please try again."
      continue
    fi
    _result="${_path}"
    return 0
  done
}

function getAvailableRepos() {
  # getAvailableRepos repos $path
  # repos must be an array
  # only repos owned by current user are returned
  local -n _repos=$1
  local _path=$2
  
  echo "---"
  echo "Searching for repos in ${GREEN}${_path}${RESET} ..."
  #find $_path -maxdepth 1 -mindepth 1 -type d -user $USER -print0 -exec basename {} \; |
  #  while IFS= read -r -d '' item; do
  #    _repos+=($item)
  #  done

  mapfile -t _repos < <(find $_path -maxdepth 1 -mindepth 1 -type d -user $USER -exec basename {} \;) # find /media/frida/borg_backup -maxdepth 1 -mindepth 1 -type d -exec basename {} \;
  echo "Number of repos found: ${#_repos[@]}"
  #echo "${_repos[@]}"
  echo "---"
}

function selectRepo() {
  # selectRepo repoPath repoName repos $pathRepos
  # set repoPath

  local -n _repoPath=$1 # return value
  local -n _repoName=$2
  local -n _repos=$3
  local _pathRepos=$4
  local _repo # for select
  local _repoPathTmp

  if [[ ${#_repos[@]} -eq 0 ]]; then
    echo "No repositories given!"
    return 1
  fi

  echo -e "${BOLD}"Select repository"${RESET}"
  
  select _repo in "${_repos[@]}"; do

    echo "---"

    if [[ -z "$_repo" ]]; then
      echo "Invalid selection, please try again."
      continue
    fi
    _repoPath="${_pathRepos}/${_repo}"
    _repoName="${_repo}"
    break
  done

  function handleOptionStrato() {
    #export BORG_REPO='${PATH_REPOS}/le-guin.home'
    #export BORG_PASSPHRASE='jy1UvLDEaYcAHD16UOJgnZoz1Lyn0Y'
    echo "Calling remote backup script '/home/borg/un.borg.backup.strato.sh' ..."
    ssh -tp 151 unonweb@strato "sudo --user borg /home/borg/un.borg.backup.strato.sh"
    backup_exit=$?
    exit $backup_exit
  }

}

function setBackupCmd() {
  # setBackupCmd cmd $repo
  local -n _cmd=$1 # return value
  local _repoName=$2

  # 2) set _cmdBackup
  case ${_repoName} in
  zapata.system)
    _cmd="backupSystem"
    ;;
  zapata.home.frida)
    _cmd="backupHome"
    ;;
  common)
    _cmd="backupCommon"
    ;;
  *)
    echo "Unknown option: ${_repoName}"
    exit 1
    ;;
  esac
}

function borgPrune() {
  # Use the `prune` subcommand to maintain 7 daily, 4 weekly and 6 monthly
  # archives of THIS machine. The '{HOSTNAME}-*' matching is very important to
  # limit prune's operation to this machine's archives and not apply to
  # other machines' archives also:
  local _pathRepo=$1

  echo "Pruning repository"
  borg prune \
    --list \
    --glob-archives '{hostname}-*' \
    --show-rc \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 1 \
    "${_pathRepo}"

  prune_exit=$?
}

function borgCompact() {
  # actually free repo disk space by compacting segments
  local _pathRepo=$1

  echo "Compacting repository"
  borg compact "${_pathRepo}"

  compact_exit=$?
}

function checks() {
  # ARGS: $pathRepo

  local _pathRepo=$1
  local _cmd=$2

  if [[ -z $_pathRepo ]]; then
    echo "_pathRepo is empty: $_pathRepo"
    exit 1
  fi

  echo "FKTN: ${GREEN}${_cmd}${RESET}"
  echo "REPO: ${GREEN}${_pathRepo}${RESET}"
  if [[ -d $_pathRepo && -w $_pathRepo ]]; then
    echo "PASS: Repo exists and is writable"
    echo "---"
  else
    echo "ERROR: Repo does not exist or is not writable!"
    exit 1
  fi

  df --human-readable --print-type "${_pathRepo}"
  echo ""

  input=
  while true; do
    echo "Hit enter to proceed!"
    read -n 1 -p ">> " -r input
    echo ""
    if [[ -z $input ]]; then
      break
    fi
  done
}

function backupSystem() {

  local _backupPath="/etc /root /var /opt"
  local _pathRepo=$1

  if [[ -z $_pathRepo ]]; then
    echo "_pathRepo is empty: $_pathRepo"
    exit 1
  fi

  echo "Starting to backup ${_backupPath}"

  sudo --set-home --preserve-env borg create ${_pathRepo}::'{hostname}-{now}' "${_backupPath}" \
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

  backup_exit=$?
}

function backupCommon() {
  # requires BORG_REPO to be set
  local _backupPath="/media/common"
  local _pathRepo=$1

  if [[ -z $_pathRepo ]]; then
    echo "_pathRepo is empty: $_pathRepo"
    exit 1
  fi

  echo "Starting to backup ${_backupPath}"

  borg create "${_pathRepo}"::'{hostname}-{now}' ${_backupPath} \
    --progress \
    --verbose \
    --filter AME \
    --list \
    --stats \
    --lock-wait 600 \
    --compression lz4 \
    --exclude-caches \
    --exclude '.Trash-1000'

  backup_exit=$?
}

function backupHome() {

  local _backupPath="/home/${USER}"
  
  local _pathRepo=$1

  if [[ -z $_pathRepo ]]; then
    echo "_pathRepo is empty: $_pathRepo"
    exit 1
  fi

  echo "Starting to backup ${_backupPath}"

  borg create "${_pathRepo}"::'{hostname}-{now}' ${_backupPath} \
    --progress \
    --verbose \
    --filter AME \
    --list \
    --stats \
    --lock-wait 600 \
    --compression lz4 \
    --exclude-caches \
    --exclude "${_backupPath}/.cache" \
    --exclude "${_backupPath}/.npm/_logs" \
    --exclude "${_backupPath}/.npm/_cacache" \
    --exclude "${_backupPath}/.config/Code/Cache" \
    --exclude "${_backupPath}/.config/Code/CachedData" \
    --exclude "${_backupPath}/.config/Code/Service Worker/ScriptCache" \
    --exclude "${_backupPath}/.config/Code/User/History" \
    --exclude "${_backupPath}/.config/libreoffice/*/cache" \
    --exclude "${_backupPath}/.local/share/Trash" \

  #2>> ${SCRIPT_NAME}.log
  backup_exit=$?
}

function mountArchive() {
  # ARGS:
  # $pathRepo $nameArchive $mountpoint
  local _pathRepo=$1
  local _nameArchive=$2
  local _mountPoint=$3
  local _cmd

  # Create mount point if it doesn't exist
  if [ ! -d "${_mountPoint}" ]; then
      echo "Creating mountpoint: ${GREEN}${_mountPoint}${RESET}"
      mkdir -p "${_mountPoint}"
  fi

  # Mount the chosen archive
  _cmd="borg mount ${_pathRepo}::${_nameArchive} ${_mountPoint}"
  echo "Mounting archive with cmd:"
  echo "${GREEN}${_cmd}${RESET}"
  ${_cmd}

  if [ $? -eq 0 ]; then
    echo "Archive mounted successfully at ${_mountPoint}"
    echo "Open with:"
    echo "nautilus ${_mountPoint} &"
    echo "Unmount with:"
    echo "umount ${_mountPoint}"
  else
      echo "Error: Failed to mount the archive."
  fi
}

function selectArchiv() {
  # ARGS: nameArchive $pathRepo

  local -n _archive=$1 # return value
  local _pathRepo=$2
  local _availableArchives
  local _arrayArchives=()
  
  # Show available archives in the chosen repository
  echo "Checking archives at ${GREEN}${_pathRepo}${RESET} ..."
  _availableArchives=$(borg list "${_pathRepo}" 2>/dev/null | awk '{print $1}')

  if [ -z "$_availableArchives" ]; then
      echo "No archives found in repository ${_pathRepo}"
  else
    # Prompt the user to choose an archive
    echo "${BOLD}Available archives:"
    _arrayArchives=($_availableArchives)
    
    select item in "${_arrayArchives[@]}"; do
        if [ -n "$item" ]; then
            echo "Archive selected: ${item}"
            _archive="${item}"
            break # return
        else
            echo "Invalid selection. Please choose a valid archive."
        fi
    done
  fi
}

function main() {

  local operations=(
    "Backup"
    "List archives"
    "Prune"
    "Compact"
    "Mount"
  )
  local op
  local index=1
  local arrRepos=()
  local pathRepo=""
  local nameRepo=""
  local nameArchive
  local cmdBackup=""
  local pathRepos=""
  local repoPaths=()

  readFileToArray repoPaths ${FILES[repoPaths]}
  trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

  selectPathToRepos pathRepos repoPaths
  # set arrRepos
  getAvailableRepos arrRepos ${pathRepos}
  # set pathRepo
  # set nameRepo
  selectRepo pathRepo nameRepo arrRepos ${pathRepos}
  # set passphrase
  echo "Enter passphrase for ${GREEN}${pathRepo}${RESET}"
  read -sp ">> " BORG_PASSPHRASE
  echo
  export BORG_PASSPHRASE

  # interactive loop
  while true; do
    echo "---"
    echo -e "${GREEN}REPO${RESET}: ${nameRepo}"
    echo
    echo -e "${BOLD}"What do you want to do?"${RESET}"
    # menu
    index=1
    for op in "${operations[@]}"; do
      echo -e "${GREEN}${index}${RESET}) ${op}"
      ((index++))
    done
    # read
    echo
    read -p ">> "
    echo

    case $REPLY in
    1)
      # Backup
      setBackupCmd cmdBackup ${nameRepo}
      checks ${pathRepo} ${cmdBackup}
      ${cmdBackup} ${pathRepo}
      ;;
    2)
      # List archives
      echo "Listing archives in ${pathRepo} ..."
      borg list ${pathRepo}
      ;;
    3)
      # Prune
      borgPrune ${pathRepo}
      ;;
    4)
      # Compact
      borgCompact ${pathRepo}
      ;;
    5)
      # Mount
      selectArchiv nameArchive ${pathRepo}
      mountArchive ${pathRepo} ${nameArchive} $MOUNT_POINT
      ;;
    *)
      echo "Invalid selection"
      sleep 1
      ;;
    esac
  done

  # use highest exit code as global exit code
  global_exit=$((backup_exit > prune_exit ? backup_exit : prune_exit))
  global_exit=$((compact_exit > global_exit ? compact_exit : global_exit))

  if [ ${global_exit} -eq 0 ]; then
    info "Backup, Prune, and Compact finished successfully"
  elif [ ${global_exit} -eq 1 ]; then
    info "Backup, Prune, and/or Compact finished with warnings"
  else
    info "Backup, Prune, and/or Compact finished with errors"
  fi

  exit ${global_exit}

}

main
