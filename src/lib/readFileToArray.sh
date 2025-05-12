function readFileToArray() { # array ${file}
    local -n result=${1}
    local file=${2}
    local lines=()
    local lines
    local ignoreComments=true
    local feedback=true
    local funcName=${FUNCNAME[0]}

    if [[ ${feedback} == true ]]; then
      echo "${GREY}--- ${funcName}()${RESET}"
    fi

    # Check if the file exists
    if [[ ! -f "${file}" ]]; then
        echo "Error: File not found: ${file}"
        return 1
    fi

    # Read the file line by line and append to the array
    while IFS= read -r line; do
      if [[ ${ignoreComments} == true ]] && [[ "${line}" == \#* ]]; then
        continue
      else
        lines+=("${line}")  # Append the line to the array
      fi
    done < "${file}"

    if [[ ${#lines[@]} -gt 0 ]]; then
        if [[ ${feedback} == true ]]; then
          echo "Found ${#lines[@]} lines"
        fi
        result=("${lines[@]}") # assign
        return 0
    else
        echo "Error: File empty? ${file}"
        return 1
    fi
}