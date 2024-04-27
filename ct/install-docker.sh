#!/usr/bin/env bash

# Copyright (c) 2021-2024 ocroguennec
# Author: ocroguennec (ocroguennec)
# License: MIT
# Base on tteck scripts https://github.com/tteck

STD=""
# This function sets various color variables using ANSI escape codes for formatting text in the terminal.
color() {
  YW=$(echo "\033[33m")
  BL=$(echo "\033[36m")
  RD=$(echo "\033[01;31m")
  BGN=$(echo "\033[4;92m")
  GN=$(echo "\033[1;92m")
  DGN=$(echo "\033[32m")
  CL=$(echo "\033[m")
  CM="${GN}✓${CL}"
  CROSS="${RD}✗${CL}"
  BFR="\\r\\033[K"
  HOLD=" "
}

# This function enables IPv6 if it's not disabled and sets verbose mode if the global variable is set to "yes"
verb_ip6() {
  if [ "$VERBOSE" = "yes" ]; then
    STD=""
  else STD="silent"; fi
  silent() { "$@" >/dev/null 2>&1; }
  if [ "$DISABLEIPV6" == "yes" ]; then
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >>/etc/sysctl.conf
    $STD sysctl -p
  fi
}

# This function enables error handling in the script by setting options and defining a trap for the ERR signal.
catch_errors() {
  set -Eeuo pipefail
  trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
}

# This function handles errors
error_handler() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null; fi
  printf "\e[?25h"
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message"
  if [[ "$line_number" -eq 23 ]]; then
    echo -e "The silent function has suppressed the error, run the script with verbose mode enabled, which will provide more detailed output.\n"
  fi
}


# This function displays an informational message with a yellow color.
msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}   "
  spinner &
  SPINNER_PID=$!
}

# This function displays a success message with a green color.
msg_ok() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null; fi
  printf "\e[?25h"
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

# This function displays a error message with a red color.
msg_error() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null; fi
  printf "\e[?25h"
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

# This function displays a spinner.
spinner() {
    local chars="/-\|"
    local spin_i=0
    printf "\e[?25l"
    while true; do
        printf "\r \e[36m%s\e[0m" "${chars:spin_i++%${#chars}:1}"
        sleep 0.1
    done
}

# Check if the shell is using bash
shell_check() {
  if [[ "$(basename "$SHELL")" != "bash" ]]; then
    clear
    msg_error "Your default shell is currently not set to Bash. To use these scripts, please switch to the Bash shell."
    echo -e "\nExiting..."
    sleep 2
    exit
  fi
}

# Run as root only
root_check() {
  if [[ "$(id -u)" -ne 0 || $(ps -o comm= -p $PPID) == "sudo" ]]; then
    clear
    msg_error "Please run this script as root."
    echo -e "\nExiting..."
    sleep 2
    exit
  fi
}


# This function updates the Container OS by running apt-get update and upgrade
update_os() {
    msg_info "Updating ${HOSTNAME} LXC Container"
    apt-get update &>/dev/null
    apt-get -y upgrade &>/dev/null
    apt-get -o Dpkg::Options::="--force-confold" -y dist-upgrade
    msg_ok "Updating ${HOSTNAME} LXC Container"
}

update_container(){
    msg_info "Updating ${HOSTNAME} LXC Container"
    apt-get update &>/dev/null
    apt-get -y upgrade &>/dev/null
    msg_ok "Updating ${HOSTNAME} LXC Container"
}


color
verb_ip6
catch_errors
update_container

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
msg_ok "Installed Dependencies"

get_latest_release() {
  curl -sL https://api.github.com/repos/$1/releases/latest | grep '"tag_name":' | cut -d'"' -f4
}

DOCKER_LATEST_VERSION=$(get_latest_release "moby/moby")
PORTAINER_LATEST_VERSION=$(get_latest_release "portainer/portainer")
PORTAINER_AGENT_LATEST_VERSION=$(get_latest_release "portainer/agent")
DOCKER_COMPOSE_LATEST_VERSION=$(get_latest_release "docker/compose")

read -r -p "Would you like to install Docker ? <y/N> " prompt
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
    msg_info "Installing Docker $DOCKER_LATEST_VERSION"
    DOCKER_CONFIG_PATH='/etc/docker/daemon.json'
    mkdir -p $(dirname $DOCKER_CONFIG_PATH)
    echo -e '{\n  "log-driver": "journald"\n}' >/etc/docker/daemon.json
    $STD sh <(curl -sSL https://get.docker.com)
    msg_ok "Installed Docker $DOCKER_LATEST_VERSION"
fi

read -r -p "Would you like to add Docker Compose? <y/N> " prompt
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  msg_info "Installing Docker Compose $DOCKER_COMPOSE_LATEST_VERSION"
  DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
  mkdir -p $DOCKER_CONFIG/cli-plugins
  curl -sSL https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_LATEST_VERSION/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
  chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
  msg_ok "Installed Docker Compose $DOCKER_COMPOSE_LATEST_VERSION"
fi

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"