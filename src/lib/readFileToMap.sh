function readFileToMap() { # _result ${_file_path}
	local -n _result=${1}
	local _file_path=${2}
	local _ignore_comments=true
	local _feedback=0

	if [[ ! -e "${_file_path}" ]]; then
		echo -e "${RED}[readFileToMap] ERROR: File not found: ${_file_path}${RESET}"
		return 1
	else
		if ((_feedback)); then
			echo "Reading ${_file_path} ..." 
		fi
  	fi

	# Read the file line by line
	while IFS='=' read -r key value; do
		# if line starts with # ignore it
		if [[ ${_ignore_comments} == true ]] && [[ "${key}" == \#* ]]; then
        	continue
		fi
		# Trim leading and trailing whitespace from key and value
		key="${key#"${key%%[![:space:]]*}"}"  # Trim leading whitespace
		key="${key%"${key##*[![:space:]]}"}"  # Trim trailing whitespace
		value="${value#"${value%%[![:space:]]*}"}"  # Trim leading whitespace
		value="${value%"${value##*[![:space:]]}"}"  # Trim trailing whitespace

		# Store the key-value pair in the associative array
		if ((_feedback)); then
			echo "${key}=${value}"
		fi
		_result["${key}"]="${value}"
	done <"${_file_path}"
}