#!/usr/bin/env bash

# Copyright (c) 2021-2024 ocroguennec
# Author: ocroguennec (ocroguennec)
# License: MIT
# Base on tteck scripts https://github.com/tteck


if [ -e "$HOME/.env" ]; then
    source "$HOME/.env";
fi

STD=""
tz=Europe/Paris
RETRY_NUM=3
RETRY_EVERY=500

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

# This function sets up the Container OS by generating the locale, setting the timezone, and checking the network connection
setting_up_container1() {
  msg_info "Setting up Container OS"
  sed -i "/$LANG/ s/\(^# \)//" /etc/locale.gen
  locale-gen >/dev/null
  echo $TZ >/etc/timezone
  ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
  for ((i = RETRY_NUM; i > 0; i--)); do
    if [ "$(hostname -I)" != "" ]; then
      break
    fi
    echo 1>&2 -en "${CROSS}${RD} No Network! "
    sleep $RETRY_EVERY
  done
  if [ "$(hostname -I)" = "" ]; then
    echo 1>&2 -e "\n${CROSS}${RD} No Network After $RETRY_NUM Tries${CL}"
    echo -e " 🖧  Check Network Settings"
    exit 1
  fi
  rm -rf /usr/lib/python3.*/EXTERNALLY-MANAGED
  systemctl disable -q --now systemd-networkd-wait-online.service
  msg_ok "Set up Container OS"
  msg_ok "Network Connected: ${BL}$(hostname -I)"
}

# This function sets up the Container OS by generating the locale, setting the timezone, and checking the network connection
setting_up_container() {
  msg_info "Setting up Container OS"
  sed -i "/$LANG/ s/\(^# \)//" /etc/locale.gen
  locale-gen >/dev/null
  echo $tz >/etc/timezone
  ln -sf /usr/share/zoneinfo/$tz /etc/localtime
  for ((i = RETRY_NUM; i > 0; i--)); do
    if [ "$(hostname -I)" != "" ]; then
      break
    fi
    echo 1>&2 -en "${CROSS}${RD} No Network! "
    sleep $RETRY_EVERY
  done
  if [ "$(hostname -I)" = "" ]; then
    echo 1>&2 -e "\n${CROSS}${RD} No Network After $RETRY_NUM Tries${CL}"
    echo -e " 🖧  Check Network Settings"
    exit 1
  fi
  rm -rf /usr/lib/python3.*/EXTERNALLY-MANAGED
  systemctl disable -q --now systemd-networkd-wait-online.service
  msg_ok "Set up Container OS"
  msg_ok "Network Connected: ${BL}$(hostname -I)"
}


# This function updates the Container OS by running apt-get update and upgrade
update_os() {
    msg_info "Updating ${HOSTNAME} LXC Container"
    apt-get update &>/dev/null
    apt-get -y upgrade &>/dev/null
    apt-get -o Dpkg::Options::="--force-confold" -y dist-upgrade &>/dev/null
    msg_ok "Updating ${HOSTNAME} LXC Container"
}

# This function checks the network connection by pinging a known IP address and prompts the user to continue if the internet is not connected
network_check() {
  set +e
  trap - ERR
  ipv4_connected=false
  ipv6_connected=false

# Check IPv4 connectivity
  if ping -c 1 -W 1 1.1.1.1 &>/dev/null; then 
    msg_ok "IPv4 Internet Connected";
    ipv4_connected=true
  else
    msg_error "IPv4 Internet Not Connected";
  fi

# Check IPv6 connectivity
  if ping6 -c 1 -W 1 2606:4700:4700::1111 &>/dev/null; then
    msg_ok "IPv6 Internet Connected";
    ipv6_connected=true
  else
    msg_error "IPv6 Internet Not Connected";
  fi

# If both IPv4 and IPv6 checks fail, prompt the user
  if [[ $ipv4_connected == false && $ipv6_connected == false ]]; then
    read -r -p "No Internet detected,would you like to continue anyway? <y/N> " prompt
    if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      echo -e " ⚠️  ${RD}Expect Issues Without Internet${CL}"
    else
      echo -e " 🖧  Check Network Settings"
      exit 1
    fi
  fi

  RESOLVEDIP=$(getent hosts github.com | awk '{ print $1 }')
  if [[ -z "$RESOLVEDIP" ]]; then msg_error "DNS Lookup Failure"; else msg_ok "DNS Resolved github.com to ${BL}$RESOLVEDIP${CL}"; fi
  set -e
  trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
}

clone_git_scripts() {
    msg_info "Installing CT Linux scripts repository on ${HOSTNAME} "
    apt-get install -y git &>/dev/null
    git clone https://github.com/newargus/home-scripts.git ./scripts
    if grep -qF "$HOME/scripts/env/bash_aliases" .bashrc;then
      echo -e "Found it"
    else
      echo -e "Sorry this string not in file"
    fi
    msg_ok "CT Linux Linux Script repository installed ${HOSTNAME} "
}



color
verb_ip6
catch_errors
setting_up_container
network_check
update_os
clone_git_scripts


