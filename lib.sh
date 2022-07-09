#!/bin/bash
# Author: Yevgeniy Goncharov aka xck, http://sys-adm.in
# Bash lib for simplification of development

set -a

# Envs
# ---------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# dir=${PWD%/*}
baseDir=$(cd -P . && pwd -P)

# Output messages
# ---------------------------------------------------\

# And colors
RED='\033[0;91m'
GREEN='\033[0;92m'
CYAN='\033[0;96m'
YELLOW='\033[0;93m'
PURPLE='\033[0;95m'
BLUE='\033[0;94m'
BOLD='\033[1m'
WHiTE="\e[1;37m"
NC='\033[0m'

ON_SUCCESS="DONE"
ON_FAIL="FAIL"
ON_ERROR="Oops"
ON_CHECK="✓"

Info() {
  echo -en "[${1}] ${GREEN}${2}${NC}\n"
}

Warn() {
  echo -en "[${1}] ${PURPLE}${2}${NC}\n"
}

Success() {
  echo -en "[${1}] ${GREEN}${2}${NC}\n"
}

Error () {
  echo -en "[${1}] ${RED}${2}${NC}\n"
}

Splash() {
  echo -en "${WHiTE} ${1}${NC}\n"
}

space() { 
  echo -e ""
}

exitNon() {
    Info "Ok, bye!"
    exit 1
}

exitOne() {
    Info "Script exit. Bye."
    exit 1
}

_exit() {
    exitOne
}

# Functions
# ---------------------------------------------------\

# Check is current user is root
isRoot() {
  if [ $(id -u) -ne 0 ]; then
    Error $ON_ERROR "You must be root user to continue"
    exit 1
  fi
  RID=$(id -u root 2>/dev/null)
  if [ $? -ne 0 ]; then
    Error "User root no found. You should create it to continue"
    exit 1
  fi
  if [ $RID -ne 0 ]; then
    Error "User root UID not equals 0. User root must have UID 0"
    exit 1
  fi
}

# Checks supporting distros
checkDistro() {
  # Checking distro
  if [ -e /etc/centos-release ]; then
      DISTRO=`cat /etc/redhat-release | awk '{print $1,$4}'`
      RPM=1
  elif [ -e /etc/fedora-release ]; then
      DISTRO=`cat /etc/fedora-release | awk '{print ($1,$3~/^[0-9]/?$3:$4)}'`
      RPM=2
  elif [ -e /etc/os-release ]; then
    DISTRO=`lsb_release -d | awk -F"\t" '{print $2}'`
    RPM=0
    DEB=1
  else
      Error "Your distribution is not supported (yet)"
      exit 1
  fi
}

get_distro() {
    case $(uname | tr '[:upper:]' '[:lower:]') in
      linux*)
        OS=linux
        ;;
      darwin*)
        OS=osx
        ;;
      msys*)
        OS=windows
        ;;
      *)
        OS=none
        ;;
    esac

    echo ${OS}
}

# Yes / No confirmation
confirm() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

# get Actual date
getDate() {
    date '+%d-%m-%Y_%H-%M-%S'
}

# As example for password generation
getRandom() {
  local l=$1
  [ "$l" == "" ] && l=8
  tr -dc A-Za-z0-9 < /dev/urandom | head -c ${l} | xargs
}

getRandomComplex() {
  local l=$1
  [ "$l" == "" ] && l=8
  tr -dc 'A-Za-z0-9!?#$%^&()=+-' < /dev/urandom | head -c ${l} | xargs
}

# Checking active status from systemd unit
service_exists() {
    local n=$1
    if [[ $(systemctl list-units --all -t service --full --no-legend "$n.service" | sed 's/^\s*//g' | cut -f1 -d' ') == $n.service ]]; then
        return 0
    else
        return 1
    fi
}

# SELinux status
isSELinux() {

    if [[ "$RPM" -eq "1" ]]; then
        selinuxenabled
        if [ $? -ne 0 ]
        then
            Error "SELinux:\t\t" "DISABLED"
            return 0
        else
            Info "SELinux:\t\t" "ENABLED"
            return 1
        fi
    fi

}

# If file exist true / false
file_exist() {
    local f=$1

    if [[ -f $f ]]; then
        return 1
    else
        return 0
    fi
}

dir_exist() {
    local d=$1

    if [[ -d $d ]]; then
        return 1
    else
        return 0
    fi
}

dir_or_file_exist() {
    local df=$1

    if [[ -d $df ]]; then
        return 1
    elif [[ -f $df ]]; then
        return 1
    else
        return 0
    fi
}

# Unit services status
chk_SvsStatus() {
    systemctl is-active --quiet $1 && Info "$1: " "Running" || Error "$1: " "Stopped"
}

# Checking active status from systemd unit (prev)
chk_SvcExist() {
    local n=$1
    if [[ $(systemctl list-units --all -t service --full --no-legend "$n.service" | cut -f1 -d' ') == $n.service ]]; then
        return 0
    else
        return 1
    fi
}

# Checking active status from systemd unit (latest)
service_exists() {
    local n=$1
    if [[ $(systemctl list-units --all -t service --full --no-legend "$n.service" | sed 's/^\s*//g' | cut -f1 -d' ') == $n.service ]]; then
        return 0
    else
        return 1
    fi
}


allowFirewalldService() {
    #statements
    firewall-cmd --permanent --zone=$2 --add-service=$1
}