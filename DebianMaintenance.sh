#!/usr/bin/env bash

# Andre Augusto Giannotti Scota (https://sites.google.com/view/a2gs/)

# Script exit if a command fails:
#set -e

# Script exit if a referenced variable is not declared:
#set -u

# If one command in a pipeline fails, its exit code will be returned as the result of the whole pipeline:
#set -o pipefail

# Activate tracing:
#set -x

#trap "" SIGINT

function usageHelp
{
	echo -e "$0 Usage:\n"
	echo -e "$0\n\tNormal executation\n"
	echo -e "$0 2>log\n\tNormal executation with log\n"
	echo -e "$0 -d 2>log\n\tNormal executation with full log\n"
	echo -e "$0 -s\n\tDo not delete tempfile cmd output commands (/tmp)\n"
}

# ---------------------------------------------

function clearPrintExit
{
	clear
	[ "$DEBUG_MAINTENANCE" = true ] && echo "$2" >&2
	exit "$1"
}

function getAppPath
{
	if [ -z "$1" ]
	then
		return 1
	fi

	retWhich=$(which "$1")
	if [ "$?" -ne 0 ]
	then
		[ "$DEBUG_MAINTENANCE" = true ] && echo "Application [$1] is mandatory!." >&2
		return 1
	fi

	[ "$DEBUG_MAINTENANCE" = true ] && echo "Application [$1] found as [$retWhich]" >&2

	echo "$retWhich"
	return 0
}

function deleteFile
{
	if [ -z "$1" ]
	then
		return 1
	fi

	RM_APP=`getAppPath 'rm'`
	if [ "$?" -eq 1 ]
	then
		"$DIALOG_APP"                            \
			--title "ERROR"                       \
			--clear                               \
			--no-collapse                         \
			--backtitle "Debian-like maintenance" \
			--msgbox "Application rm doesnot exist!" 10 50
		clearPrintExit 1 "Application rm doesnot exist!"
	fi

	if [ ! -f "$1" ] || [ -z "$1" ] || [ ! -n "$1" ]
	then
		clearPrintExit 1 "RM erro [$1] didnt delete."
	fi

	"$RM_APP" -rf "$1"
	if [ "$?" -ne 0 ]
	then
		clearPrintExit 1 "RM erro [$1] couldnt delete."
	fi

	[ "$DEBUG_MAINTENANCE" = true ] && echo "RM ok [$1] deleted." >&2
	return 0
}

function deleteCmdOutputFile
{
	if [ "$SAVE_CMD_OUTPUT" = false ]
	then
		deleteFile "$1"
	fi
}

function dumpRoutes
{
	echo "ROUTE TABLE:"
	"$IP_APP" route list
	
	echo -e "\nMULTICAST:"
	"$IP_APP" maddress show
	
	echo -e "\nNEIGHBOUR:"
	"$IP_APP" neigh show
}


function dumpNetworkFilesInfos
{
	echo -e "[/etc/hostname]\n"
	cat /etc/hostname
	echo -e "\n----------------------------------"
	
	echo -e "[/etc/hosts]\n"
	cat /etc/hosts
	echo -e "\n----------------------------------"
	
	echo -e "[/etc/networks]\n"
	cat /etc/networks
	echo -e "\n----------------------------------"
	
	echo -e "[/etc/network/interfaces]\n"
	cat /etc/network/interfaces
}

function menu_network
{
	IP_APP=`getAppPath 'ip'`
	if [ "$?" -eq 1 ]
	then
		"$DIALOG_APP"                                     \
			--title "ERROR"                                \
			--clear                                        \
			--no-collapse                                  \
			--backtitle "Debian-like maintenance: Network" \
			--msgbox "Application ip doesnot exist!" 10 50
		clearPrintExit 1 "Application ip doesnot exist!"
	fi

	while true
	do

		menuNetTempFile=`"$MKTEMP_APP" -p /tmp`
		if [ "$?" -ne 0 ]
		then
			clearPrintExit 1 "Cannot create [$menuNetTempFile]"
		fi

		"$DIALOG_APP"                                     \
			--clear                                        \
			--cancel-label "Exit"                          \
			--title "Network Menu"                         \
			--backtitle "Debian-like maintenance: Network" \
			--menu "Option:" 20 50 20                   \
			1 'List ifaces'                             \
			2 'Up/Down iface'                           \
			3 'List interface files'                    \
			4 'Show routes'                             \
			5 'ufw'                                     \
			2>$menuNetTempFile

		dialogRet=$?
		if [ "$dialogRet" -eq 1 ] || [ "$dialogRet" -eq 255 ]
		then
			deleteFile "$menuNetTempFile"
			break
		fi

		menu=`cat "$menuNetTempFile"`
		deleteFile "$menuNetTempFile"

		case $menu in
			1)
				ipaddTempFile=`"$MKTEMP_APP" -p /tmp`
				if [ "$?" -ne 0 ]
				then
					clearPrintExit 1 "Cannot create [$ipaddTempFile]"
				fi

				"$IP_APP" addr show > $ipaddTempFile

				"$DIALOG_APP"                                     \
					--no-collapse                                  \
					--clear                                        \
					--title "IP Address"                           \
					--backtitle "Debian-like maintenance: Network" \
					--textbox "$ipaddTempFile" 50 100

				deleteCmdOutputFile "$ipaddTempFile"
				;;
	
			2)
				true
				;;
	
			3)
				cfgFilesTempFile=`"$MKTEMP_APP" -p /tmp`
				if [ "$?" -ne 0 ]
				then
					clearPrintExit 1 "Cannot create [$cfgFilesTempFile]"
				fi

				dumpNetworkFilesInfos > $cfgFilesTempFile
	
				"$DIALOG_APP"                                     \
					--no-collapse                                  \
					--clear                                        \
					--title "Network Files"                        \
					--backtitle "Debian-like maintenance: Network" \
					--textbox "$cfgFilesTempFile" 50 100
	
				deleteCmdOutputFile "$cfgFilesTempFile"
				;;
	
			4)
				routesTempFile=`"$MKTEMP_APP" -p /tmp`
				if [ "$?" -ne 0 ]
				then
					clearPrintExit 1 "Cannot create [$routesTempFile]"
				fi

				dumpRoutes > $routesTempFile
	
				"$DIALOG_APP"                                     \
					--no-collapsexi                                \
					--clear                                        \
					--title "Network Route"                        \
					--backtitle "Debian-like maintenance: Network" \
					--textbox "$routesTempFile" 50 100

				deleteCmdOutputFile "$routesTempFile"
				;;
	
			5) true
				;;
	
			6) true
				;;
	
			*) echo "Unknow network menu option: $menu" >&2
				;;
		esac
	done
}

function menu_services
{
# systemctl list-unit-files --type service --state enabled,generated
# systemctl list-units --type service --state running
# systemctl list-units --type service --state failed
# systemctl list-units --type service --state 


# MENU:
# 1 - Start/Stop/Restart
# 2 - List status
# 2 - List status failed


	true
}

function menu_hd
{
	LSBLK_APP=`getAppPath 'lsblk'`
	if [ "$?" -eq 1 ]
	then
		"$DIALOG_APP"                                           \
			--title "ERROR"                                      \
			--no-collapse                                        \
			--clear                                              \
			--backtitle "Debian-like maintenance: Block Devices" \
			--msgbox "Application lsblk doesnot exist!" 10 50
		clearPrintExit 1 "Application lsblk doesnot exist!"
	fi

	menuHDTempFile=`"$MKTEMP_APP" -p /tmp`
	if [ "$?" -ne 0 ]
	then
		clearPrintExit 1 "Cannot create [$menuHDTempFile]"
	fi

	"$LSBLK_APP" -ampfz > $menuHDTempFile
	
	"$DIALOG_APP"                                           \
		--no-collapse                                        \
		--clear                                              \
		--title "Block Devices"                              \
		--backtitle "Debian-like maintenance: Block Devices" \
		--textbox "$menuHDTempFile" 20 100
	
	deleteCmdOutputFile "$menuHDTempFile"

	true
}

function menu_memory
{
	true
}

function menu_sekurity
{
#		# Set /etc/rkhunter.conf
#		#PKGMGR=DPKG
#		#UPDATE_MIRRORS=0 to UPDATE_MIRRORS=1
#		#MIRRORS_MODE=1 to MIRRORS_MODE=0
#		#WEB_CMD="/bin/false" to WEB_CMD=""

	while true
	do

		menuSekTempFile=`"$MKTEMP_APP" -p /tmp`
		if [ "$?" -ne 0 ]
		then
			clearPrintExit 1 "Cannot create [$menuSekTempFile]"
		fi

		"$DIALOG_APP"                                      \
			--clear                                         \
			--cancel-label "Exit"                           \
			--title "Sekurity Menu"                         \
			--backtitle "Debian-like maintenance: Security" \
			--menu "Option:" 20 50 20                       \
			1 "Update and run clamscan"                     \
			2 "Update and run rkhunter"                     \
			3 "Update and run lynis"                        \
			4 "Run chkrootkit"                              \
			2>$menuSekTempFile

		dialogRet=$?
		if [ "$dialogRet" -eq 1 ] || [ "$dialogRet" -eq 255 ]
		then
			deleteFile "$menuSekTempFile"
			break
		fi

		menu=`cat "$menuSekTempFile"`
		deleteFile "$menuSekTempFile"

		case $menu in
			1)
				FRESHCLAM_APP=`getAppPath 'freshclam'`
				if [ "$?" -eq 1 ]
				then
					"$DIALOG_APP"                                      \
						--title "ERROR"                                 \
						--no-collapse                                   \
						--backtitle "Debian-like maintenance: Security" \
						--clear                                         \
						--msgbox "Application freshclam doesnot exist!" 10 50
					[ "$DEBUG_MAINTENANCE" = true ] && echo "Application freshclam doesnot exist!" >&2
					continue
				fi

				CLAMSCAN_APP=`getAppPath 'clamscan'`
				if [ "$?" -eq 1 ]
				then
					"$DIALOG_APP"                                      \
						--title "ERROR"                                 \
						--no-collapse                                   \
						--clear                                         \
						--backtitle "Debian-like maintenance: Security" \
						--msgbox "Application clamscan doesnot exist!" 10 50
					[ "$DEBUG_MAINTENANCE" = true ] && echo "Application clamscan doesnot exist!" >&2
					continue
				fi

				"$FRESHCLAM_APP"
				"$CLAMSCAN_APP" -r -i /

				echo 'Pause. Press [ENTER].'; read
				;;

			2)
				RKHUNTER_APP=`getAppPath 'rkhunter'`
				if [ "$?" -eq 1 ]
				then
					"$DIALOG_APP"                                      \
						--title "ERROR"                                 \
						--no-collapse                                   \
						--clear                                         \
						--backtitle "Debian-like maintenance: Security" \
						--msgbox "Application rkhunter doesnot exist!" 10 50
					[ "$DEBUG_MAINTENANCE" = true ] && echo "Application rkhunter doesnot exist!" >&2
					continue
				fi

				"$RKHUNTER_APP" --update
				"$RKHUNTER_APP" -c --sk

				echo 'Pause. Press [ENTER].'; read
				;;

			3)
				LYNIS_APP=`getAppPath 'lynis'`
				if [ "$?" -eq 1 ]
				then
					"$DIALOG_APP"                                      \
						--title "ERROR"                                 \
						--no-collapse                                   \
						--clear                                         \
						--backtitle "Debian-like maintenance: Security" \
						--msgbox "Application lynis doesnot exist!" 10 50
					[ "$DEBUG_MAINTENANCE" = true ] && echo "Application lynis doesnot exist!" >&2
					continue
				fi

				"$LYNIS_APP" update info
				"$LYNIS_APP" audit system

				echo 'Pause. Press [ENTER].'; read
				;;

			4)
				CHKROOTKIT_APP=`getAppPath 'chkrootkit'`
				if [ "$?" -eq 1 ]
				then
					"$DIALOG_APP"                                      \
						--title "ERROR"                                 \
						--no-collapse                                   \
						--clear                                         \
						--backtitle "Debian-like maintenance: Security" \
						--msgbox "Application chkrootkit doesnot exist!" 10 50
					[ "$DEBUG_MAINTENANCE" = true ] && echo "Application chkrootkit doesnot exist!" >&2
					break
				fi

				"$CHKROOTKIT_APP"

				echo 'Pause. Press [ENTER].'; read
				;;

			*)
				echo "Unknow sekurity option: $menu" >&2
				;;
		esac
	done
}

function packagesManuallyList
{
	APT_APP=`getAppPath 'apt'`
	if [ "$?" -eq 1 ]
	then
		"$DIALOG_APP"                                      \
			--title "ERROR"                                 \
			--no-collapse                                   \
			--clear                                         \
			--backtitle "Debian-like maintenance: Packages" \
			--msgbox "Application apt doesnot exist!" 10 50
		clearPrintExit 1 "Application apt doesnot exist!"
	fi

	menuAptTempFile=`"$MKTEMP_APP" -p /tmp`
	if [ "$?" -ne 0 ]
	then
		clearPrintExit 1 "Cannot create [$menuAptTempFile]"
	fi

	"$APT_APP" list --manual-installed > $menuAptTempFile

	"$DIALOG_APP"                                      \
		--no-collapse                                   \
		--clear                                         \
		--title "Manual Installed"                      \
		--backtitle "Debian-like maintenance: Packages" \
		--textbox "$menuAptTempFile" 20 100
	
	deleteCmdOutputFile "$menuAptTempFile"

	true
}

function packagesList
{
	DPKG_APP=`getAppPath 'dpkg'`
	if [ "$?" -eq 1 ]
	then
		"$DIALOG_APP"                                      \
			--title "ERROR"                                 \
			--no-collapse                                   \
			--clear                                         \
			--backtitle "Debian-like maintenance: Packages" \
			--msgbox "Application dpkg doesnot exist!" 10 50
		clearPrintExit 1 "Application dpkg doesnot exist!"
	fi

	menuDPkgPackTempFile=`"$MKTEMP_APP" -p /tmp`

	"$DIALOG_APP"                                      \
		--clear                                         \
		--no-collapse                                   \
		--title "Packages list"                         \
		--backtitle "Debian-like maintenance: Packages" \
		--inputbox "Enter package name pattern to search:" 8 40 2>$menuDPkgPackTempFile

	packName=`cat "$menuDPkgPackTempFile"`
	deleteFile "$menuDPkgPackTempFile"

	menuDPkgTempFile=`"$MKTEMP_APP" -p /tmp`
	if [ "$?" -ne 0 ]
	then
		clearPrintExit 1 "Cannot create [$menuDPkgTempFile]"
	fi

	if [ -z "$packName" ]
	then
		"$DPKG_APP" -l > $menuDPkgTempFile
	else
		APTCACHE_APP=`getAppPath 'apt-cache'`
		if [ "$?" -eq 0 ]
		then
			"$APTCACHE_APP" search "$packName" > $menuDPkgTempFile
			echo -e "\n\n" >> $menuDPkgTempFile
		fi

		"$DPKG_APP" -l "$packName" >> $menuDPkgTempFile
	fi

	"$DIALOG_APP"                                      \
		--no-collapse                                   \
		--clear                                         \
		--title "Packages list"                         \
		--backtitle "Debian-like maintenance: Packages" \
		--textbox "$menuDPkgTempFile" 20 100
	
	deleteCmdOutputFile "$menuDPkgTempFile"
}

function listSearchPackagesMenu
{
	while true
	do
		menuListSearchPackTempFile=`"$MKTEMP_APP" -p /tmp`
		if [ "$?" -ne 0 ]
		then
			clearPrintExit 1 "Cannot create [$menuListSearchPackTempFile]"
		fi

		"$DIALOG_APP"                                         \
			--clear                                            \
			--title "List/search Packages"                     \
			--backtitle "Debian-like maintenance: Packages"       \
			--cancel-label "Exit"                              \
			--menu "Option:"                                   \
			20 80 20                                           \
			1 'Search a installed  package (empty = list all)' \
			2 'List manually installed'                        \
			2>$menuListSearchPackTempFile
			
		dialogRet=$?
		if [ "$dialogRet" -eq 1 ] || [ "$dialogRet" -eq 255 ]
		then
			deleteFile "$menuListSearchPackTempFile"
			break
		fi
	
		menu=`cat "$menuListSearchPackTempFile"`
		deleteFile "$menuListSearchPackTempFile"

		case $menu in
			1)
				packagesList
				;;

			2)
				packagesManuallyList
				;;

			*)
				echo "Unknow utilities menu option: $menu" >&2
				;;

		esac
	done
}

function packageInstallRemovePurge
{
	APTGET_APP=`getAppPath 'apt-get'`
	if [ "$?" -eq 1 ]
	then
		"$DIALOG_APP"                                      \
			--title "ERROR"                                 \
			--no-collapse                                   \
			--clear                                         \
			--backtitle "Debian-like maintenance: Packages" \
			--msgbox "Application apt-get doesnot exist!" 10 50
		[ "$DEBUG_MAINTENANCE" = true ] && echo "Application apt-get doesnot exist!" >&2
		break
	fi

	while true
	do
		menuPackIRPTempFile=`"$MKTEMP_APP" -p /tmp`
		if [ "$?" -ne 0 ]
		then
			clearPrintExit 1 "Cannot create [$menuPackIRPTempFile]"
		fi

		"$DIALOG_APP"                                   \
			--clear                                      \
			--title "Packages Menu"                      \
			--backtitle "Debian-like maintenance: Packages" \
			--cancel-label "Exit"                        \
			--menu "Option:" 20 50 20                    \
			1 'Install'                                  \
			2 'Remove'                                   \
			3 'Purge'                                    \
			2>$menuPackIRPTempFile

		dialogRet=$?
		if [ "$dialogRet" -eq 1 ] || [ "$dialogRet" -eq 255 ]
		then
			deleteFile "$menuPackIRPTempFile"
			break
		fi
	
		menu=`cat "$menuPackIRPTempFile"`
		deleteFile "$menuPackIRPTempFile"

		case $menu in
			1)
				true
				;;
	
			2)
				true
				;;
	
			3)
				true
				;;

			*) echo "Unknow package option: $menu" >&2
				;;
	
		esac

	done
}

function packageInfo
{
	APTCACHE_APP=`getAppPath 'apt-cache'`
	if [ "$?" -eq 1 ]
	then
		"$DIALOG_APP"                                      \
			--title "ERROR"                                 \
			--clear                                         \
			--no-collapse                                   \
			--backtitle "Debian-like maintenance: Packages" \
			--msgbox "Application apt-cache doesnot exist!" 10 50
		clearPrintExit 1 "Application apt-cache doesnot exist!"
	fi

	menuDPkgPackTempFile=`"$MKTEMP_APP" -p /tmp`

	"$DIALOG_APP"                                      \
		--clear                                         \
		--no-collapse                                   \
		--title "Package Info"                          \
		--backtitle "Debian-like maintenance: Packages" \
		--inputbox "Enter package name pattern to search:" 8 40 2>$menuDPkgPackTempFile

	packName=`cat "$menuDPkgPackTempFile"`
	deleteFile "$menuDPkgPackTempFile"

	menuDPkgTempFile=`"$MKTEMP_APP" -p /tmp`
	if [ "$?" -ne 0 ]
	then
		clearPrintExit 1 "Cannot create [$menuDPkgTempFile]"
	fi

	"$APTCACHE_APP" show "$packName" > $menuDPkgTempFile
	if [ "$?" -ne 0 ]
	then
		echo "Package \"$packName\" not found." > $menuDPkgTempFile
	fi

	"$DIALOG_APP"                                      \
		--clear                                         \
		--no-collapse                                   \
		--title "Packages Info"                         \
		--backtitle "Debian-like maintenance: Packages" \
		--textbox "$menuDPkgTempFile" 20 100
	
	deleteCmdOutputFile "$menuDPkgTempFile"
}

function menu_packages
{
	APTGET_APP=`getAppPath 'apt'`
	if [ "$?" -eq 1 ]
	then
		"$DIALOG_APP"                                      \
			--title "ERROR"                                 \
			--no-collapse                                   \
			--clear                                         \
			--backtitle "Debian-like maintenance: Packages" \
			--msgbox "Application apt doesnot exist!" 10 50
		clearPrintExit 1 "Application apt doesnot exist!"
	fi

	while true
	do
		menuPackTempFile=`"$MKTEMP_APP" -p /tmp`
		if [ "$?" -ne 0 ]
		then
			clearPrintExit 1 "Cannot create [$menuPackTempFile]"
		fi

		"$DIALOG_APP"                                   \
			--clear                                      \
			--title "Packages Menu"                      \
			--backtitle "Debian-like maintenance: Packages" \
			--cancel-label "Exit"                        \
			--menu "Option:" 20 50 20                    \
			1 'Update'                                   \
			2 'Simulate'                                 \
			3 'Upgrade'                                  \
			4 'Distro upgrade'                           \
			5 'System release info'                      \
			6 'Clean old instalations'                   \
			7 'List and search installed packages'       \
			8 'Package information'                      \
			9 'Install, remove or puge a package'        \
			2>$menuPackTempFile

		dialogRet=$?
		if [ "$dialogRet" -eq 1 ] || [ "$dialogRet" -eq 255 ]
		then
			deleteFile "$menuPackTempFile"
			break
		fi
	
		menu=`cat "$menuPackTempFile"`
		deleteFile "$menuPackTempFile"

		case $menu in
			1)
				clear
				"$APTGET_APP" -y update
				if [ "$?" -ne 0 ]
				then
					echo 'apt-get update error. Pause. Press [ENTER].'; read
					clear
					exit 1
				fi
				;;
	
			2)
				clear
				"$APTGET_APP" --simulate upgrade
				echo 'Pause. Press [ENTER].'; read
				;;
	
			3)
				clear
				"$APTGET_APP" -y upgrade
				if [ "$?" -ne 0 ]
				then
					echo 'apt-get update error. Pause. Press [ENTER].'; read
					clear
					exit 1
				fi
				;;
	
			4)
				clear
				"$APTGET_APP" -y dist-upgrade
				if [ "$?" -ne 0 ]
				then
					echo 'apt-get update error. Pause. Press [ENTER].'; read
					clear
					exit 1
				fi
				;;
	
			5)
				true
				;;
	
			6)
				clear
				"$APTGET_APP" -y autoremove
				"$APTGET_APP" -y autoclean
				"$APTGET_APP" -y clean
				"$APTGET_APP" -y purge
				"$APTGET_APP" -y check
				;;

			7)
				listSearchPackagesMenu
				;;

			8)
				packageInfo
				;;

			9)
				packageInstallRemovePurge
				;;

			*) echo "Unknow package option: $menu" >&2
				;;
	
		esac
	done
}

function dumpOSInfo
{
	echo 'OPERATION SYSTEM:'
	uname -a
	cat /etc/debian_version
	lsb_release -a
}

function dumpHWInfo
{
	echo 'HARDWARE:'
	
	echo '=== [ lspci ] ==================================================================================='
	lspci
	lspci -vv
	echo '=== [ /proc/cpuinfo ] ==========================================================================='
	cat /proc/cpuinfo
	echo '=== [ lsblk ] ==================================================================================='
	lsblk --output-all --all
	echo '=== [ biosdecode ] =============================================================================='
	biosdecode
	echo '=== [ dmidecode ] ==============================================================================='
	dmidecode
	echo '=== [ lshw ] ===================================================================================='
	lshw -short
	lshw -numeric
}

function menu_utilities
{
	while true
	do
		menuUtilTempFile=`"$MKTEMP_APP" -p /tmp`
		if [ "$?" -ne 0 ]
		then
			clearPrintExit 1 "Cannot create [$menuUtilTempFile]"
		fi

		"$DIALOG_APP"                                    \
			--clear                                       \
			--title "Utilities"                           \
			--backtitle "Debian-like maintenance: Utilities" \
			--cancel-label "Exit"                         \
			--menu "Option:"                              \
			20 50 20                                      \
			1 'top'                                       \
			2 'mc'                                        \
			3 'dmesg'                                     \
			4 'iptraf-ng'                                 \
			9 'Run cmd as root...'                        \
			2>$menuUtilTempFile
			
		dialogRet=$?
		if [ "$dialogRet" -eq 1 ] || [ "$dialogRet" -eq 255 ]
		then
			deleteFile "$menuUtilTempFile"
			break
		fi
	
		menu=`cat "$menuUtilTempFile"`
		deleteFile "$menuUtilTempFile"

		case $menu in
			1)
				HTOP_APP=`getAppPath 'htop'`
				if [ "$?" -eq 1 ]
				then

					# at least 'top'?
					TOP_APP=`getAppPath 'top'`
					if [ "$?" -eq 1 ]
					then

						"$DIALOG_APP"                                       \
							--clear                                          \
							--title "ERROR"                                  \
							--no-collapse                                    \
							--backtitle "Debian-like maintenance: Utilities" \
							--msgbox "Application htop or top doesnot exist!" 10 50
						clearPrintExit 1 "Application htop or top doesnot exist!"
					fi

					"$(TOP_APP)"

				else
					"$HTOP_APP"
				fi
				;;
	
			2)
				MC_APP=`getAppPath 'mc'`
				if [ "$?" -eq 1 ]
				then
					"$DIALOG_APP"                                       \
						--title "ERROR"                                  \
						--clear                                          \
						--no-collapse                                    \
						--backtitle "Debian-like maintenance: Utilities" \
						--msgbox "Application mc doesnot exist!" 10 50
					clearPrintExit 1 "Application mc doesnot exist!"
				fi

				"$MC_APP"
				;;

			3)
				dmesgOutputTempFile=`"$MKTEMP_APP" -p /tmp`
				if [ ! -f "$dmesgOutputTempFile" ]
				then
					clearPrintExit 1 "$dmesgOutputTempFile error."
				fi

				DMESG_APP=`getAppPath 'dmesg'`
				if [ "$?" -eq 1 ]
				then
					"$DIALOG_APP"                                       \
						--clear                                          \
						--title "ERROR"                                  \
						--no-collapse                                    \
						--backtitle "Debian-like maintenance: Utilities" \
						--msgbox "Application dmesg doesnot exist!" 10 50
					deleteCmdOutputFile "$dmesgOutputTempFile"
					clearPrintExit 1 "Application dmesg doesnot exist!"
				fi

				"$DMESG_APP" -P > $dmesgOutputTempFile
				if [ "$?" -ne "0" ]
				then
					deleteCmdOutputFile "$dmesgOutputTempFile"
					clearPrintExit 1 "dmesg return error."
				fi

				"$DIALOG_APP"                                       \
					--no-collapse                                    \
					--title "DMesg"                                  \
					--clear                                          \
					--backtitle "Debian-like maintenance: Utilities" \
					--textbox "$dmesgOutputTempFile" 50 100

				deleteCmdOutputFile "$dmesgOutputTempFile"
				;;

			4)
				IPTRAF_APP=`getAppPath 'iptraf-ng'`
				if [ "$?" -eq 1 ]
				then
					"$DIALOG_APP"                                       \
						--title "ERROR"                                  \
						--no-collapse                                    \
						--clear                                          \
						--backtitle "Debian-like maintenance: Utilities" \
						--msgbox "Application iptraf-ng doesnot exist!" 10 50
					clearPrintExit 1 "Application mc doesnot exist!"
				fi

				"$IPTRAF_APP"
				;;

			9) # i dont give a fuck what are you going to do with it

				runAsRootTempFile=`"$MKTEMP_APP" -p /tmp`
				if [ "$?" -ne 0 ]
				then
					clearPrintExit 1 "Cannot create [$runAsRootTempFile]"
				fi
				"$DIALOG_APP"                                             \
					--clear                                                \
					--no-collapse                                          \
					--title "Run as Root"                                  \
					--backtitle "Debian-like maintenance: Run cmd as root" \
					--inputbox "Run as root..." 8 40 2>$runAsRootTempFile

				CMDTORUN=`cat "$runAsRootTempFile"`
				deleteFile "$runAsRootTempFile"

				[ "$DEBUG_MAINTENANCE" = true ] && echo "RUNNING AS ROOT: [$CMDTORUN]" >&2

				runAsRootOutputTempFile=`"$MKTEMP_APP" -p /tmp`
				if [ "$?" -ne 0 ]
				then
					clearPrintExit 1 "Cannot create [$runAsRootOutputTempFile]"
				fi

				$CMDTORUN > $runAsRootOutputTempFile 2>&1
				cmdRet=$?

				echo -e "\nCMD RUN AS ROOT RETURNED SHELL CODE: [$cmdRet]" >>$runAsRootOutputTempFile

				"$DIALOG_APP"                                             \
					--no-collapse                                          \
					--clear                                                \
					--title "Run as Root Output"                           \
					--backtitle "Debian-like maintenance: Run cmd as root" \
					--textbox "$runAsRootOutputTempFile" 50 100

				[ "$DEBUG_MAINTENANCE" = true ] && cat "$runAsRootOutputTempFile" >&2

				deleteCmdOutputFile "$runAsRootOutputTempFile"
				;;

			*)
				echo "Unknow utilities menu option: $menu" >&2
				;;

		esac
	done
}

# -------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------

if [ $(id -u) -ne 0 ]; then
    echo 'Run as root.' >&2
    exit 1
fi

MKTEMP_APP=`getAppPath 'mktemp'`
if [ "$?" -eq 1 ]
then
	"$DIALOG_APP"                            \
		--title "ERROR"                       \
		--no-collapse                         \
		--clear                               \
		--backtitle "Debian-like maintenance" \
		--msgbox "Application mktemp doesnot exist!" 10 50
	clearPrintExit 1 "Application mktemp doesnot exist!"
fi

DIALOG_APP=`getAppPath 'dialog'`
if [ "$?" -eq 1 ]
then
	clearPrintExit 1 "Application dialog doesnot exist!"
fi

DEBUG_MAINTENANCE=false
SAVE_CMD_OUTPUT=false

#while getopts ":s:p:" o; do
while getopts ":ds" argvopts;
do
	case ${argvopts} in
#		p)
#			s=${OPTARG}
#			((s == 45 || s == 90)) || usage
#			;;
		d)
			DEBUG_MAINTENANCE=true
			;;
		s)
			SAVE_CMD_OUTPUT=true
			;;
		*)
			usageHelp
			exit 1
			;;
	esac
done

while true
do
	menuTempFile=`"$MKTEMP_APP" -p /tmp`
	if [ "$?" -ne 0 ]
	then
		[ "$DEBUG_MAINTENANCE" = true ] && echo "Cannot create [$menuTempFile]" >&2
		exit 1
	fi

	"$DIALOG_APP"                            \
		--clear                               \
		--title "Main Menu"                   \
		--backtitle "Debian-like maintenance" \
		--cancel-label "Exit"                 \
		--menu "Option:"                      \
		20 50 20                              \
		1 'Network'                           \
		2 'HD'                                \
		3 'Memory'                            \
		4 'Packages'                          \
		5 'Services'                          \
		6 'LKM'                               \
		7 'Sekurity'                          \
		9 'System info'                       \
		u 'Utilities'                         \
		2>$menuTempFile

	dialogRet=$?
	if [ "$dialogRet" -eq 1 ] || [ "$dialogRet" -eq 255 ]
	then
		deleteFile "$menuTempFile"
		break
	fi

	menu=`cat "$menuTempFile"`
	deleteFile "$menuTempFile"

	case $menu in
		1)
			menu_network
			;;

		2)
			menu_hd
			;;

		3)
			menu_memory
			;;

		4)
			menu_packages
			;;

		5)
			menu_services
			;;

		6)
			true
			;;

		7)
			menu_sekurity 
			;;

		9)
			menuGetInfoTemFile=`"$MKTEMP_APP" -p /tmp`
			if [ "$?" -ne 0 ]
			then
				clearPrintExit 1 "Cannot create [$menuGetInfoTemFile]"
			fi

			dumpOSInfo > $menuGetInfoTemFile
	
			echo -e "\n" >> $menuGetInfoTemFile

			dumpHWInfo >> $menuGetInfoTemFile

			"$DIALOG_APP"                                    \
				--no-collapse                                 \
				--clear                                       \
				--title "System Info"                         \
				--backtitle "Debian-like maintenance: System" \
				--textbox "$menuGetInfoTemFile" 50 100

			deleteCmdOutputFile "$menuGetInfoTemFile"
			;;

		u)
			menu_utilities
			;;

		*)
			echo "Unknow main menu option: [$menu]" >&2
			;;

	esac
done

clear
exit 0
