readonly red="\e[0;31m"
readonly green="\e[0;32m"
readonly yellow="\e[0;33m"
readonly blue="\e[0;34m"
readonly reset="\e[0m"

function now () {
    date +'%Y-%m-%dT%H:%M:%S%z'
}

function log_info () {
    echo -e "${yellow}[$(now)]${green} ${1}${reset}"
}

function log_error () {
    echo -e "${yellow}[$(now)]${red} ${1}${reset}"
}
