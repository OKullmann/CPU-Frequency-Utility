#!/bin/bash

# CFU is designed to run the cpufrequtils package in openSUSE.
# Copyright (C) 2011 by James D. McDaniel, jmcdaniel3@austin.rr.com
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
#: Last Edit   : Sun Jul 10 09:10:00 CDT 2011
#: Author      : J. McDaniel
#: Version     : 1.10
#: Description : display and set CPU Frequency
#: Options     : [sudo] cfu [-s #2 #3 #4]
#: Notes       : cfu will ask to install cpufrequtils if not installed

TITLE="CPU Frequency Utility - Version 1.10"

#
# Written for the openSUSE forums on Sunday July 10, 2011
#

#
# Copy and Paste the text of this script into a text editor and save 
# it as the file cfu in the /home area bin folder 
# example is: /home/username/bin, also known as ~/bin
# This script must be marked executable to be used.  Please  
# run the following Terminal command: chmod +x ~/bin/cfu
# To use cfu, open a terminal session and type in: cfu
#

declare -a governs
declare -a spdsteps

#
# CFU Help Display Function
#

function help {
    cat << EOFHELP
                     $TITLE
C.F.U. requires no Startup Options, However if you use them, your choices are:
cfu [-h --help] ; shows this help <OR> cfu [-s [#2 #3 #4]] ; selects CPU speed
-s = Select Governor
#2 = Governor's per menu options 1 through 5
#3 = q to Quit cfu <OR> #3 = userspace Governor speed options 1 to max speed #
#4 = q to Quit when Governor was userspace
Examples: [sudo] cfu -s 5 q  <OR>  [sudo] cfu -s 2 1 q
NOTES: To Change your CPU Governor and CPU Speed requires root user authority.
       Using C.F.U. requires that you have installed the cpufrequtils package.
EOFHELP
exit 0
}

#
# Display C.F.U. Help if requested.
#

case "$1" in
    -h|--help) help ;;
esac

#
# Determine if cpufreq is supported on this PC
#

if [ $(($(find /sys/devices/system/cpu/cpu*/cpufreq 2>/dev/null | wc -l) + $(ls /sys/devices/system/cpu/cpufreq 2>/dev/null | wc -l))) -eq 0 ] ; then
  echo "The cpufreq Utilities will not work on this PC.  You may want to uninstall the cpufrequtils package if installed!"
  exit 1
fi

#
# Find the brand/model of the CPU in this PC
#

if [ -f /proc/cpuinfo ]; then
    cpuname=$(grep -m 1 "model name" /proc/cpuinfo | cut -d: -f2 | sed -e 's/^ *//' | sed -e 's/$//')
fi

# Remove Extra Spaces in $cpuname if they should exist

cpuname=$(echo "$cpuname" |awk '{$1=$1}1' OFS=" ")

#
# Find out number of CPU cores, Hyper-threading will double this number
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
# Format RAW CPU Speed Display function
#

function form_speed {
  spd=$1
  num1=$(((spd) / 1000 ))
  formed=$(printf "%'d GHz\n" $num1)
  formed=$(echo $formed | tr ',' '.')
}

#
# Locate Substring by space seperator in a long string  
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
# Load Substrings into an array ${governs[0]}
# Uses user Function called sub_string
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
# Display Main Menu function
#

function main_menu {
echo $TITLE
echo "CPU Name: $cpuname"
if $hyper ; then
  echo "CPU Cores: $Number_CPUS ($threads with Hyper-Threading)"
else
  echo "CPU Cores: $Number_CPUS"
fi
echo "CPU Speed: $freq"
echo "Speed Range: $lowest to $highest"
echo "Governor: $policy"
echo "Your $totopt Options: $govern"
echo " Please make your selection, S=Set Governor or Q=Quit (S/Q): "
echo "$l1"
}

#
# Set Speed Governor with cpufreq-set for ALL CPU's
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
# Set CPU speed when governor=userspace with cpufreq-set for ALL CPU's
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
  echo "The CPU frequency Utilities Package is not installed!"
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
# Main Program Starts Here *****************************************
#

gui=true

while $gui ; do

#
# Find Active CPU Speed - cpufreq-info -f
#

  freq=$(cpufreq-info -f)
  form_speed "$freq"
  freq=$formed

#
# Find Lowest Speed / Highest Speed / CPU Speed Policy - cpufreq-info -p
#

  rang=$(cpufreq-info -p)
  savegovern "$rang"

#
# Set Lowest CPU Speed
#

  lowest="${governs[1]}"
  form_speed "$lowest"
  lowest=$formed

#
# Set Highest CPU Speed
#

  highest="${governs[2]}"
  form_speed "$highest"
  highest=$formed

#
# Set CPU Speed Policy
#

  policy="${governs[3]}"
  policy=$(echo $policy | tr '[a-z]' '[A-Z]')

#
# Determine userspace speeds which can be used and load into array
#

# See if scaling_available_frequencies file is present for usage bu C.F.U.

  freqfile="/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies"

  if [ ! -e "$freqfile" ] ; then

# Locate Just speed Listing Sub-string for CPU 0 if above file not found

    ffile=false
    cpuspd=$(cpufreq-info -c 0)
    cpuspd=${cpuspd%" available cpufreq governors"*}
    cpuspd=${cpuspd##*" available frequency steps: "}

# Breakup Speeds found into an Array
# Change all spaces to Underscore
# Then Change all commas to spaces

    cpuspd=$(echo $cpuspd | tr ' ' '_')
    cpuspd=$(echo $cpuspd | tr ',' ' ')
  else
    ffile=true
    cpuspd=$(cat $freqfile)
  fi

  savegovern "$cpuspd"
  totspd="$?"

# Move array values from governs to spdsteps
# Change all Underscores to spaces
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
# Policy Selections cpufreq-info -g
#

  govern=$(cpufreq-info -g)
  savegovern "$govern"
  totopt="$?"
  govern=$(echo $govern | tr '[a-z]' '[A-Z]')
  govern=$(echo $govern | tr ' ' ',')

#
# Show Main Menu and request user input
#

  main_menu

# Check for Input option menu Automation

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
# CPU Speed Governor Selection
#

  if [[ $CHOICE == [Ss] ]] ; then
    echo "CPU Governor Speed Selection Menu"
    echo
    echo "CONSERVATIVE - Similar to ondemand, but more conservative "
    echo "(clock speed changes are more graceful)."
    echo "USERSPACE - Manually configured clock speeds by user."
    echo "POWERSAVE - Runs the CPU at minimum speed." 
    echo "ONDEMAND - Dynamically increases/decreases the CPU(s)"
    echo "clock speed based on system load."
    echo "PERFORMANCE - Runs the CPU(s) at maximum clock speed." 
    echo
    echo "The Active Governor is: $policy"
    echo
    counter=0
    while [[ counter -lt totopt ]] ; do
      let counter=counter+1
      echo "$counter) ${governs[$counter]}"
    done
    echo
    echo -n "Enter the Governor Number to use [1-$((totopt))] (q=Quit):"

# Check for Input option menu Automation
    
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
# CPU Speed Selection when Governor is set to userspace
#

        if [ "${governs[$CHOICE]}" == "userspace" ] ; then
	  setfreq 1
	  echo 
	  echo "CPU USERSPACE Speed Selection Menu"
	  echo
	  counter=0
	  while [[ counter -lt totspd ]] ; do
	    let counter=counter+1
	    echo "$counter) ${spdsteps[$counter]}"
	  done
          echo 
	  echo -n "Enter the CPU Speed Number to use [1-$((totspd))]:"

# Check for Input option menu Automation
	  
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
# End Of Script
