#!/bin/bash

# CFU is designed to run the cpufrequtils package in openSUSE.
# Copyright (C) 2011 by James D. McDaniel, Oliver Kullmann
# (jmcdaniel3@austin.rr.com)
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

#: Title       : cfu - CPU Frequency Utility
#: Date Created: Wed Jun 22 17:03:27 CDT 2011
#: Authors     : J. McDaniel, Oliver Kullmann
#: Description : display and set CPU frequency
#: Options     : [sudo] cfu [-s #2 #3 #4]
#: Notes       : cfu will ask to install cpufrequtils if not installed

# set -o errexit
# set -o nounset

version=1.11
TITLE="CPU Frequency Utility - Version ${version}"

declare -a governs
declare -a spdsteps

#
# CFU help display function
#

function help {
    cat << EOFHELP
                     $TITLE
C.F.U. requires no startup options, However if you use them, your choices are:
cfu [-h --help] ; shows this help <OR> cfu [-s [#2 #3 #4]] ; selects CPU speed
-s = select governor
#2 = governor's per menu options 1 through 5
#3 = q to quit cfu or #3 = userspace governor speed options 1 to max speed #
#4 = q to quit when governor was userspace
Examples: [sudo] cfu -s 5 q  <or>  [sudo] cfu -s 2 1 q
NOTES: To change your CPU governor and CPU speed requires root user authority.
       Using C.F.U. requires that you have installed the cpufrequtils package.
EOFHELP
exit 0
}

#
# Display CFU help if requested.
#

case "$1" in
    -h|--help) help ;;
esac

#
# Determine if cpufreq is supported on this PC
#

if [ $(($(find /sys/devices/system/cpu/cpu*/cpufreq 2>/dev/null | wc -l) + $(ls /sys/devices/system/cpu/cpufreq 2>/dev/null | wc -l))) -eq 0 ] ; then
  echo "The cpufreq utilities will not work on this PC.  You may want to uninstall the cpufrequtils package if installed!"
  exit 1
fi

#
# Find the brand/model of the CPU in this PC
#

if [ -f /proc/cpuinfo ]; then
    cpuname=$(grep -m 1 "model name" /proc/cpuinfo | cut -d: -f2 | sed -e 's/^ *//' | sed -e 's/$//')
fi

# Remove extra spaces in $cpuname if they should exist

cpuname=$(echo "$cpuname" |awk '{$1=$1}1' OFS=" ")

#
# Find out number of CPU cores, hyper-threading will double this number
#

threads=$(getconf _NPROCESSORS_ONLN)
Number_CPUS=$(grep -m 1 "cpu cores" /proc/cpuinfo | cut -d: -f2 | sed -e 's/^ *//' | sed -e 's/$//')
hyper=false
if [[ $(cat /proc/cpuinfo) = *siblings* ]] ; then
  hyperthreads=$(grep -m 1 "siblings" /proc/cpuinfo | cut -d: -f2 | sed -e 's/^ *//' | sed -e 's/$//')
  if [ $((Number_CPUS)) -lt $((hyperthreads)) ] ; then
    hyper=true
  fi
fi

#
# Format raw CPU speed display function
#

function form_speed {
  spd=$1
  num1=$(((spd) / 1000 ))
  formed=$(printf "%'d GHz\n" $num1)
  formed=$(echo $formed | tr ',' '.')
}

#
# Locate substring by space seperator in a long string
#

function sub_string {
  counter=$1
  start=$2
  num2=${#start}
  while [ $(( counter )) -lt $(( num2 + 1 )) ] ; do
  temp="${start:$(($counter)):1}"
  if [[ $temp != " " ]] ; then
    let counter=counter+1
  else
    return ${counter}
  fi
  done
  return ${counter}
}

#
# Load substrings into an array ${governs[0]}
# Uses user function called sub_string
#

function savegovern {
savgov=$1
string=$savgov; string="${string//[^ ]/}"
let string=${#string}+1
place=0
glen=0
while [[ place -lt string ]] ; do
  let place=place+1
  savlst=$((glen))
  sub_string "$glen" "$savgov"
  glen="$?"
  governs[$place]="${savgov:$((savlst)):$((glen-savlst))}"

  if [ "$ffile" == "true" ] ; then
    form_speed "${governs[$place]}"
    governs[$place]="$formed"
  fi

  let glen=glen+1
done
return ${place}
}

#
# Display main menu function
#

function main_menu {
echo $TITLE
echo "CPU name: $cpuname"
if $hyper ; then
  echo "CPU cores: $Number_CPUS ($threads with hyper-threading)"
else
  echo "CPU cores: $Number_CPUS"
fi
echo "CPU speed: $freq"
echo "Speed range: $lowest to $highest"
echo "Governor: $policy"
echo "Your $totopt options: $govern"
echo " Please make your selection, \"s\" to set governor or \"q\" to quit: "
echo "$l1"
}

#
# Set speed governor with cpufreq-set for all CPU's
#

function govern_set {
  countII=0
  while [[ countII -lt threads ]] ; do
    sudo cpufreq-set -c $((countII)) -g "$1"
    let countII=countII+1
  done
  sleep 1
}

#
# Set CPU speed when governor=userspace with cpufreq-set for all CPU's
#

function setfreq {
  freqset="${spdsteps[$1]}"
  freqlen=${#freqset}
  let freqlen=freqlen-4
  freqset=${freqset:0:$((freqlen))}
  countII=0
  while [[ countII -lt threads ]] ; do
    sudo cpufreq-set -c $((countII)) -f $freqset"GHz"
    let countII=countII+1
  done
  sleep 1
}

# ----------------------------------------------------------------------------------------------------
# Prepair for install of cpufrequtils if needed by more than one distro
# The following coding provided by please_try_again
#

# install cpufrequtils under openSUSE, Fedora, Mandriva, Ubuntu
suselinux="zypper in"
mandrivalinux="urpmi"
fedora="yum install"
ubuntu="apt-get install"

# default to openSUSE if lsb_release is not found (or write more code to install
# lsb_release withouth confirmation or get the release name in another way)
install=suselinux
which lsb_release &>/dev/null && install=$(lsb_release -is | tr "[:upper:]" "[:lower:]" | tr -d " ")
install=${!install}
#----------------------------------------------------------------------------------------------------

#
# Determine if the package cpufrequtils is installed
#

which cpufreq-info > /dev/null
Exit_Code=$?
if [ $(( Exit_Code )) -ge 1 ] ; then
  echo "The CPU frequency utilities package is not installed!"
  echo
  echo -n "Would you like to install the cpufrequtils package(y/N)?"
  read CHOICE
  if [[ $CHOICE == [Yy] ]] ; then
    sudo $install cpufrequtils
  else
    exit 1
  fi
fi

#
# Main program starts here *****************************************
#
gui=true
while $gui ; do
#
# Find active CPU speed - cpufreq-info -f
#
  freq=$(cpufreq-info -f)
  form_speed "$freq"
  freq=$formed
#
# Find lowest speed / highest speed / CPU speed policy - cpufreq-info -p
#
  range_output=$(cpufreq-info -l)
  savegovern "${range_output}"
#
# Set lowest CPU speed
#
  lowest="${governs[1]}"
  form_speed "$lowest"
  lowest=$formed
#
# Set highest CPU speed
#
  highest="${governs[2]}"
  form_speed "$highest"
  highest=$formed
#
# Set CPU speed policy
#
  policy_output=$(cpufreq-info -p)
  savegovern "${policy_output}"
  policy="${governs[3]}"
  policy=$(echo $policy | tr '[a-z]' '[A-Z]')
#
# Determine userspace speeds which can be used and load into array
#
# See if scaling_available_frequencies file is present for usage bu C.F.U.
  freqfile="/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies"
  if [ ! -e "$freqfile" ] ; then
# Locate just speed Listing Sub-string for CPU 0 if above file not found
    ffile=false
    cpuspd=$(cpufreq-info -c 0)
    cpuspd=${cpuspd%" available cpufreq governors"*}
    cpuspd=${cpuspd##*" available frequency steps: "}
# Breakup speeds found into an array
# Change all spaces to underscore
# Then change all commas to spaces
    cpuspd=$(echo $cpuspd | tr ' ' '_')
    cpuspd=$(echo $cpuspd | tr ',' ' ')
  else
    ffile=true
    cpuspd=$(cat $freqfile)
  fi
  savegovern "$cpuspd"
  totspd="$?"
# Move array values from governs to spdsteps
# Change all underscores to spaces
# Trim off excess spaces
  ffile=false
  counter=0
  while [[ counter -lt totspd ]] ; do
    let counter=counter+1
    spdsteps[$counter]=$( echo ${governs[$counter]} | tr '_' ' ')
    tmpspd=${spdsteps[$counter]}
    if [ "${tmpspd:0:1}" == " " ] ; then
      tmpspd="${tmpspd:1:${#tmpspd}-1}"
      spdsteps[$counter]=$tmpspd
    fi
  done
  if [ "${spdsteps[$totspd]}" == "0 GHz" ] ; then
    let totspd=totspd-1
  fi
#
# Policy selections cpufreq-info -g
#
  govern=$(cpufreq-info -g)
  savegovern "$govern"
  totopt="$?"
  govern=$(echo $govern | tr '[a-z]' '[A-Z]')
  govern=$(echo $govern | tr ' ' ',')
#
# Show main menu and request user input
#
  main_menu
# Check for input option menu automation
  if [ "$1" == "-s" -o "$1" == "-S" ] ; then
    CHOICE="s"
    shift
  else
    if [ "$1" == "q" -o "$1" == "Q" ] ; then
      CHOICE="q"
    else
      read CHOICE
    fi
  fi
#
# CPU speed governor selection
#
  if [[ $CHOICE == [Ss] ]] ; then
    echo "CPU governor speed selection menu"
    echo
    echo "CONSERVATIVE - similar to ondemand, but more conservative "
    echo "(clock speed changes are more graceful)."
    echo "USERSPACE - manually configured clock speeds by user."
    echo "POWERSAVE - runs the CPU at minimum speed."
    echo "ONDEMAND - dynamically increases/decreases the CPU(s)"
    echo "clock speed based on system load."
    echo "PERFORMANCE - runs the CPU(s) at maximum clock speed."
    echo
    echo "The active governor is: $policy"
    echo
    counter=0
    while [[ counter -lt totopt ]] ; do
      let counter=counter+1
      echo "$counter) ${governs[$counter]}"
    done
    echo
    echo -n "Enter the governor number to use [1-$((totopt))] (q for quit):"
# Check for input option menu automation
    if [[ $1 -le $totopt ]] && [[ $1 -gt 0 ]] ; then
      CHOICE=$1
      shift
    else
      read CHOICE
    fi
    if [[ $CHOICE =~ ^[0-9]+$ ]] ; then
      if [[ $CHOICE -le $counter ]] && [[ $CHOICE -gt 0 ]]; then
        govern_set "${governs[$CHOICE]}"
#
# CPU speed selection when governor is set to userspace
#
        if [ "${governs[$CHOICE]}" == "userspace" ] ; then
	  setfreq 1
	  echo 
	  echo "CPU USERSPACE speed selection menu"
	  echo
	  counter=0
	  while [[ counter -lt totspd ]] ; do
	    let counter=counter+1
	    echo "$counter) ${spdsteps[$counter]}"
	  done
          echo 
	  echo -n "Enter the CPU speed number to use [1-$((totspd))]:"
# Check for input option menu automation
	  if [[ $1 -le $totspd ]] && [[ $1 -gt 0 ]] ; then
	    CHOICE=$1
	    shift
	  else
	    read CHOICE
	  fi
	  if [[ $CHOICE =~ ^[0-9]+$ ]] ; then
	    if [[ $CHOICE -le $counter ]] && [[ $CHOICE -gt 0 ]]; then
	      setfreq "$CHOICE"
            fi
          fi
        fi
      fi
    else 
      gui=false
    fi
  fi
    if [[ $CHOICE == [Qq] ]] ; then
      gui=false
    fi
done

exit 0
