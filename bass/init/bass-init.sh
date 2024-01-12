#
# Copyright (C) 2024 Bliss Co-Labs
#
# License: GNU Public License v2 or later
#

function set_custom_package_perms()
{
	# Set up custom package permissions

	current_user=$(dumpsys activity | grep mCurrentUserId | cut -d: -f2)

	# KioskLauncher
	exists_kiosk=$(pm list packages org.blissos.kiosklauncher | grep -c org.blissos.kiosklauncher)
	if [ $exists_kiosk -eq 1 ]; then
		pm set-home-activity "org.blissos.kiosklauncher/.ui.MainActivity"
		am start -a android.intent.action.MAIN -c android.intent.category.HOME
	fi

	# MultiClientIME
	exists_mcime=$(pm list packages com.example.android.multiclientinputmethod | grep -c com.example.android.multiclientinputmethod)
	if [ $exists_mcime -eq 1 ]; then
		# Enable desktop mode on external display (required for MultiDisplay Input)
		settings put global force_desktop_mode_on_external_displays 1
	fi

	# ZQYMultiClientIME
	exists_zqymcime=$(pm list packages com.zqy.multidisplayinput | grep -c com.zqy.multidisplayinput)
	if [ $exists_zqymcime -eq 1 ]; then
		# Enable desktop mode on external display (required for MultiDisplay Input)
		settings put global force_desktop_mode_on_external_displays 1
	fi

	# BlissRestrictedLauncher
	exists_restlauncher=$(pm list packages com.bliss.restrictedlauncher | grep -c com.bliss.restrictedlauncher)
	if [ $exists_restlauncher -eq 1 ]; then
		if [ ! -f /data/misc/rlconfig/admin ]; then
			# set device admin
			dpm set-device-owner com.bliss.restrictedlauncher/.DeviceAdmin
			mkdir -p /data/misc/rlconfig
			touch /data/misc/rlconfig/admin
			chown 1000.1000 /data/misc/rlconfig /data/misc/rlconfig/*
			chmod 775 /data/misc/rlconfig
			chmod 664 /data/misc/rlconfig/admin
		fi
				
		pm grant com.bliss.restrictedlauncher android.permission.SYSTEM_ALERT_WINDOW
		pm set-home-activity "com.bliss.restrictedlauncher/.activities.LauncherActivity"
		am start -a android.intent.action.MAIN -c android.intent.category.HOME
	fi

	# Game-Mode Launcher
	exists_molla=$(pm list packages com.sinu.molla | grep -c com.sinu.molla)
	if [ $exists_molla -eq 1 ]; then
		pm set-home-activity "com.sinu.molla/.MainActivity"
		am start -a android.intent.action.MAIN -c android.intent.category.HOME
	fi

	# Game-Mode Launcher
	exists_cross=$(pm list packages id.psw.vshlauncher | grep -c id.psw.vshlauncher)
	if [ $exists_cross -eq 1 ]; then
		pm set-home-activity "id.psw.vshlauncher/.activities.Xmb"
		am start -a android.intent.action.MAIN -c android.intent.category.HOME
	fi

	# Garlic-Launcher
	exists_garliclauncher=$(pm list packages com.sagiadinos.garlic.launcher | grep -c com.sagiadinos.garlic.launcher)
	if [ $exists_garliclauncher -eq 1 ]; then
		if [ ! -f /data/misc/glauncherconfig/admin ]; then
			# set device admin
			dpm set-device-owner com.sagiadinos.garlic.launcher/.receiver.AdminReceiver
			mkdir -p /data/misc/glauncherconfig
			touch /data/misc/glauncherconfig/admin
			chown 1000.1000 /data/misc/glauncherconfig /data/misc/glauncherconfig/*
			chmod 775 /data/misc/glauncherconfig
			chmod 664 /data/misc/glauncherconfig/admin
		fi
		pm set-home-activity "com.sagiadinos.garlic.launcher/.MainActivity"
		am start -a android.intent.action.MAIN -c android.intent.category.HOME
	fi
		
	# SmartDock
	exists_smartdock=$(pm list packages cu.axel.smartdock | grep -c cu.axel.smartdock)
	if [ $exists_smartdock -eq 1 ]; then
		pm grant cu.axel.smartdock android.permission.SYSTEM_ALERT_WINDOW
		pm grant cu.axel.smartdock android.permission.GET_TASKS
		pm grant cu.axel.smartdock android.permission.REORDER_TASKS
		pm grant cu.axel.smartdock android.permission.REMOVE_TASKS
		pm grant cu.axel.smartdock android.permission.ACCESS_WIFI_STATE
		pm grant cu.axel.smartdock android.permission.CHANGE_WIFI_STATE
		pm grant cu.axel.smartdock android.permission.ACCESS_NETWORK_STATE
		pm grant cu.axel.smartdock android.permission.ACCESS_COARSE_LOCATION
		pm grant cu.axel.smartdock android.permission.ACCESS_FINE_LOCATION
		pm grant cu.axel.smartdock android.permission.READ_EXTERNAL_STORAGE
		pm grant cu.axel.smartdock android.permission.MANAGE_USERS
		pm grant cu.axel.smartdock android.permission.BLUETOOTH_ADMIN
		pm grant cu.axel.smartdock android.permission.BLUETOOTH_CONNECT
		pm grant cu.axel.smartdock android.permission.BLUETOOTH
		pm grant cu.axel.smartdock android.permission.REQUEST_DELETE_PACKAGES
		pm grant cu.axel.smartdock android.permission.ACCESS_SUPERUSER
		pm grant cu.axel.smartdock android.permission.PACKAGE_USAGE_STATS
		pm grant cu.axel.smartdock android.permission.QUERY_ALL_PACKAGES
		pm grant cu.axel.smartdock android.permission.WRITE_SECURE_SETTINGS
		pm grant --user $current_user cu.axel.smartdock android.permission.WRITE_SECURE_SETTINGS
		appops set cu.axel.smartdock WRITE_SECURE_SETTINGS allow
		pm grant cu.axel.smartdock android.permission.WRITE_SETTINGS
		pm grant --user $current_user cu.axel.smartdock android.permission.WRITE_SETTINGS
		appops set cu.axel.smartdock WRITE_SETTINGS allow
		pm grant cu.axel.smartdock android.permission.BIND_ACCESSIBILITY_SERVICE
		pm grant --user $current_user cu.axel.smartdock android.permission.BIND_ACCESSIBILITY_SERVICE
		appops set cu.axel.smartdock BIND_ACCESSIBILITY_SERVICE allow
		pm grant cu.axel.smartdock android.permission.BIND_NOTIFICATION_LISTENER_SERVICE
		pm grant --user $current_user cu.axel.smartdock android.permission.BIND_NOTIFICATION_LISTENER_SERVICE
		appops set cu.axel.smartdock BIND_NOTIFICATION_LISTENER_SERVICE allow
		pm grant cu.axel.smartdock android.permission.BIND_DEVICE_ADMIN
		pm grant --user $current_user cu.axel.smartdock android.permission.BIND_DEVICE_ADMIN
		appops set cu.axel.smartdock BIND_DEVICE_ADMIN allow
		pm grant cu.axel.smartdock android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
		pm grant --user $current_user cu.axel.smartdock android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS

		# set overlays enabled
		settings put secure secure_overlay_settings 1

		# allow displaying over other apps if in Go mode
		settings put system alert_window_bypass_low_ram 1

		# Only if PC_MODE is 1
		if [ $PC_MODE -eq 1 ]; then
			
			if [ ! -f /data/misc/sdconfig/accessibility ] && ! pm list packages | grep -q "com.blissos.setupwizard"; then
				# set accessibility services
				eas=$(settings get secure enabled_accessibility_services)
				if [ -n "$eas" ]; then
					settings put secure enabled_accessibility_services $eas:cu.axel.smartdock/cu.axel.smartdock.services.DockService
				else
					settings put secure enabled_accessibility_services cu.axel.smartdock/cu.axel.smartdock.services.DockService
				fi
				mkdir -p /data/misc/sdconfig
				touch /data/misc/sdconfig/accessibility
				chown 1000.1000 /data/misc/sdconfig /data/misc/sdconfig/*
				chmod 775 /data/misc/sdconfig
				chmod 664 /data/misc/sdconfig/accessibility
			fi
			if [ ! -f /data/misc/sdconfig/notification ]; then
				# set notification listeners
				enl=$(settings get secure enabled_notification_listeners)
				if [ -n "$enl" ]; then
					settings put secure enabled_notification_listeners $enl:cu.axel.smartdock/cu.axel.smartdock.services.NotificationService
					
				else
					settings put secure enabled_notification_listeners cu.axel.smartdock/cu.axel.smartdock.services.NotificationService
				fi
				mkdir -p /data/misc/sdconfig
				touch /data/misc/sdconfig/notification
				chown 1000.1000 /data/misc/sdconfig /data/misc/sdconfig/*
				chmod 775 /data/misc/sdconfig
				chmod 664 /data/misc/sdconfig/notification
			fi
			if [ ! -f /data/misc/sdconfig/admin ]; then
				# set device admin
				dpm set-active-admin --user current cu.axel.smartdock/android.app.admin.DeviceAdminReceiver
				mkdir -p /data/misc/sdconfig
				touch /data/misc/sdconfig/admin
				chown 1000.1000 /data/misc/sdconfig /data/misc/sdconfig/*
				chmod 775 /data/misc/sdconfig
				chmod 664 /data/misc/sdconfig/admin
			fi

			if [ $(settings get global development_settings_enabled) == 0 ]; then
		    	settings put global development_settings_enabled 1
			fi

			[ -n "$SET_SMARTDOCK_DEFAULT" ] && pm set-home-activity "cu.axel.smartdock/.activities.LauncherActivity" || pm set-home-activity "com.android.launcher3/.LauncherProvider"
			
		fi
	fi

	# com.farmerbb.taskbar
	exists_taskbar=$(pm list packages com.farmerbb.taskbar | grep -c com.farmerbb.taskbar)
	if [ $exists_taskbar -eq 1 ]; then
		pm grant com.farmerbb.taskbar android.permission.PACKAGE_USAGE_STATS
		pm grant --user $current_user com.farmerbb.taskbar android.permission.WRITE_SECURE_SETTINGS
		appops set com.farmerbb.taskbar BIND_DEVICE_ADMIN allow
		pm grant com.farmerbb.taskbar android.permission.GET_TASKS
		pm grant com.farmerbb.taskbar android.permission.BIND_CONTROLS
		pm grant com.farmerbb.taskbar android.permission.BIND_INPUT_METHOD
		pm grant com.farmerbb.taskbar android.permission.BIND_QUICK_SETTINGS_TILE
		pm grant com.farmerbb.taskbar android.permission.REBOOT
		pm grant --user $current_user com.farmerbb.taskbar android.permission.BIND_ACCESSIBILITY_SERVICE
		appops set com.farmerbb.taskbar BIND_ACCESSIBILITY_SERVICE allow
		pm grant --user $current_user com.farmerbb.taskbar android.permission.MANAGE_OVERLAY_PERMISSION
		appops set com.farmerbb.taskbar MANAGE_OVERLAY_PERMISSION allow
		pm grant com.farmerbb.taskbar android.permission.SYSTEM_ALERT_WINDOW
		pm grant com.farmerbb.taskbar android.permission.USE_FULL_SCREEN_INTENT

		# set overlays enabled
		settings put secure secure_overlay_settings 1
	fi

	# MicroG: com.google.android.gms
	is_microg=$(dumpsys package com.google.android.gms | grep -m 1 -c org.microg.gms)
	if [ $is_microg -eq 1 ]; then
		exists_gms=$(pm list packages com.google.android.gms | grep -c com.google.android.gms)
		if [ $exists_gms -eq 1 ]; then
			pm grant com.google.android.gms android.permission.ACCESS_FINE_LOCATION
			pm grant com.google.android.gms android.permission.READ_EXTERNAL_STORAGE
			pm grant com.google.android.gms android.permission.ACCESS_BACKGROUND_LOCATION
			pm grant com.google.android.gms android.permission.ACCESS_COARSE_UPDATES
			pm grant --user $current_user com.google.android.gms android.permission.FAKE_PACKAGE_SIGNATURE
			appops set com.google.android.gms android.permission.FAKE_PACKAGE_SIGNATURE
			pm grant --user $current_user com.google.android.gms android.permission.MICROG_SPOOF_SIGNATURE
			appops set com.google.android.gms android.permission.MICROG_SPOOF_SIGNATURE
			pm grant --user $current_user com.google.android.gms android.permission.WRITE_SECURE_SETTINGS
			appops set com.google.android.gms android.permission.WRITE_SECURE_SETTINGS
			pm grant com.google.android.gms android.permission.SYSTEM_ALERT_WINDOW
			pm grant --user $current_user com.google.android.gms android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
			appops set com.google.android.gms android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
		fi
		exists_vending=$(pm list packages com.google.android.vending | grep -c com.google.android.vending)
		if [ $exists_vending -eq 1 ]; then
			pm grant --user $current_user com.google.android.vending android.permission.FAKE_PACKAGE_SIGNATURE
			appops set com.google.android.vending android.permission.FAKE_PACKAGE_SIGNATURE
		fi
	fi
	
}

function set_usb_mode()
{
	# Set up usb/adb props when values are detected in /proc/cmdline
	
	for c in `cat /proc/cmdline`; do
		case $c in
			*=*)
				eval $c
				if [ -z "$1" ]; then
					case $c in
						FORCE_USE_ADB_CLIENT_MODE=2)
							set_property persist.adb.notify 0
							set_property ro.secure 0
							set_property ro.adb.secure 0
							set_property ro.debuggable 1
							set_property service.adb.root 1
							set_property persist.sys.root_access 1
							set_property persist.service.adb.enable 1
							set_property service.adb.tcp.port 5555
							;;
						FORCE_USE_ADB_CLIENT_MODE=1)
							set_property persist.usb.debug 1
							set_property persist.adb.notify 0
							set_property persist.sys.usb.config "mtp,adb"
							set_property ro.secure 0
							set_property ro.adb.secure 0
							set_property ro.debuggable 1
							set_property service.adb.root 1
							set_property persist.sys.root_access 1
							set_property persist.service.adb.enable 1
							set_property service.adb.tcp.port 5555
							;;
						FORCE_USE_ADB_CLIENT_MODE=0)
							set_property persist.usb.debug 0
							set_property persist.adb.notify 1
							set_property persist.sys.usb.config "mtp"
							set_property ro.secure 1
							set_property ro.adb.secure 1
							set_property ro.debuggable 0
							set_property service.adb.root 0
							set_property persist.sys.root_access 0
							set_property persist.service.adb.enable 0
							set_property service.adb.tcp.port 5555
							;;
						FORCE_USE_ADB_MASS_STORAGE=*)
							usb_config=$(getprop persist.sys.usb.config)
							if [ "$FORCE_USE_ADB_MASS_STORAGE" == 1 ]; then
								ms_value=",mass_storage"
							else
								ms_value=""
							fi
							if [ -z "$usb_config" ]; then
						        set_property persist.sys.usb.config "$ms_value"
							else
								set_property persist.sys.usb.config "$usb_config$ms_value"
							fi
        					set_property persist.usb.debug "$FORCE_USE_ADB_MASS_STORAGE"
							;;
					esac
				fi
				;;
		esac
	done
}

function set_max_logd()
{
	for c in `cat /proc/cmdline`; do
		case $c in
			*=*)
				eval $c
				if [ -z "$1" ]; then
					case $c in
						# Set TimeZone
						SET_MAX_LOGD=*)
							if [ "$SET_MAX_LOGD" == 1 ]; then
								size_value="8388608"
								radio_size_value="4M"
								system_size_value="4M"
								crash_size_value="1M"
							else
								size_value=""
								radio_size_value=""
								system_size_value=""
								crash_size_value=""
							fi
							setprop persist.logd.size "$size_value"
							setprop persist.logd.size.radio "$radio_size_value"
							setprop persist.logd.size.system "$system_size_value"
							setprop persist.logd.size.crash "$crash_size_value"
							;;
					esac
				fi
				;;
		esac
	done
	
}

function set_package_opts()
{
	# Set generic package options
	# Example: HIDE_APPS="com.android.settings,com.aurora.services,com.termux,com.android.vending"
	# 		   UNHIDE_APPS="com.android.settings,com.aurora.services,com.termux,com.android.vending"
	#		   DISABLE_APPS="com.aurora.services,com.android.contacts,com.android.dialer"
	# 		   ENABLE_APPS="com.aurora.services,com.android.contacts,com.android.dialer,com.android.messaging"
	# 
	# Note: Be careful about what apps you disable, enable or hide. Some apps are required for other
	# functions, like org.zeroxlab.util.tscal while others can not be disabled and only hidden, 
	# like com.android.settings
	for c in `cat /proc/cmdline`; do
        case $c in
            *=*)
                eval $c
                if [ -z "$1" ]; then
                    case $c in
                        HIDE_APPS=*)
                            hapackages="${HIDE_APPS#*=}"
							hapackage_array=($(echo $hapackages | sed 's/,/ /g' | xargs))
                            for hapackage in "${hapackage_array[@]}"; do
								if [ ! -f /data/misc/bbconfig/$hapackage ]; then
									echo "HIDE_APPS: $hapackage"
									pm hide $hapackage
									sleep 1
									mkdir -p /data/misc/bbconfig
									touch /data/misc/bbconfig/$hapackage
								fi
                            done
                            ;;
                        RESTORE_APPS=*)
                            rapackages="${RESTORE_APPS#*=}"
							rapackage_array=($(echo $rapackages | sed 's/,/ /g' | xargs))
                            for rapackage in "${rapackage_array[@]}"; do
								if [ -f /data/misc/bbconfig/$rapackage ]; then
									echo "RESTORE_APPS: $rapackage"
									pm unhide $rapackage
									sleep 1
									rm -rf /data/misc/bbconfig/$rapackage
								fi
                            done
                            ;;
                    esac
                fi
                ;;
        esac
    done
	
}

function set_custom_settings()
{
	# Set generic device settings
	# Example: SET_SCREEN_OFF_TIMEOUT=1800000 # 30 minutes 
	# 		   SET_SLEEP_TIMEOUT=86400000 # 1 day
	#
	for c in `cat /proc/cmdline`; do
        case $c in
            *=*)
                eval $c
                if [ -z "$1" ]; then
                    case $c in
						SET_SCREEN_OFF_TIMEOUT=*)
							# Set screen off timeout
							# options: integer in milliseconds
							settings put system screen_off_timeout "$SET_SCREEN_OFF_TIMEOUT"
							;;
						SET_SLEEP_TIMEOUT=*)
							# Set screen sleep timeout
							# options: integer in milliseconds
							settings put system sleep_timeout "$SET_SLEEP_TIMEOUT"
							;;
						SET_POWER_ALWAYS_ON=*)
							# Set power always on
							# options: true or false
							svc power stayon "$SET_POWER_ALWAYS_ON"
							;;
						SET_STAY_ON_WHILE_PLUGGED_IN=*)
							# Set stay on while plugged in
							# options: true or false
							settings put global stay_on_while_plugged_in "$SET_STAY_ON_WHILE_PLUGGED_IN"
							;;
						FORCE_BLUETOOTH_SERVICE=*)
							# Set force bluetooth service state
							# options: enable, disable
							pm "$FORCE_BLUETOOTH_SERVICE" com.android.bluetooth
							svc bluetooth "$FORCE_BLUETOOTH_SERVICE"
							;;
						FORCE_DISABLE_ALL_RADIOS=1)
							# Set force disable all radios
							settings put global airplane_mode_radios cell,wifi,bluetooth,nfc,wimax
							settings put global airplane_mode_toggleable_radios ""
							settings put secure sysui_qs_tiles "rotation,caffeine,$(settings get secure sysui_qs_tiles)"
							cmd connectivity airplane-mode enable
							;;
						
                    esac
                fi
                ;;
        esac
    done
	
}

