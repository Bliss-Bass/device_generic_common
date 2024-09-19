#
# Copyright (C) 2013-2018 The Android-x86 Open Source Project
#
# License: GNU Public License v2 or later
#

function set_property()
{
	setprop "$1" "$2"
	[ -n "$DEBUG" ] && echo "$1"="$2" >> /dev/x86.prop
}

function set_prop_if_empty()
{
	[ -z "$(getprop $1)" ] && set_property "$1" "$2"
}

function rmmod_if_exist()
{
	for m in $*; do
		[ -d /sys/module/$m ] && rmmod $m
	done
}

function init_misc()
{
	# a hack for USB modem
	lsusb | grep 1a8d:1000 && eject

	# in case no cpu governor driver autoloads
	[ -d /sys/devices/system/cpu/cpu0/cpufreq ] || modprobe acpi-cpufreq

	# Allow for adjusting intel_pstate max/min freq on boot
	if [ -n "$INTEL_PSTATE_CPU_MIN_PERF_PCT"  ]; then
		echo $INTEL_PSTATE_CPU_MIN_PERF_PCT > /sys/devices/system/cpu/intel_pstate/min_perf_pct
	fi
	
	if [ -n "$INTEL_PSTATE_CPU_MAX_PERF_PCT"  ]; then
		echo $INTEL_PSTATE_CPU_MAX_PERF_PCT > /sys/devices/system/cpu/intel_pstate/max_perf_pct
	fi

	# Allow for adjusting cpu energy performance
	# Normal options: default, performance, balance_performance, balance_power, power
	if [ -n "$CPU_ENERGY_PERFORMANCE_PREF"  ]; then

		cpuprefavailable=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences)
		
		# if the word "CPU_ENERGY_PERFORMANCE_PREF" is found in the $cpuprefavailable string, then set the options for all cpus
		if [[ "$cpuprefavailable" == *"$CPU_ENERGY_PERFORMANCE_PREF"* ]]; then
			for cpu in $(ls -d /sys/devices/system/cpu/cpu?); do
				echo $CPU_ENERGY_PERFORMANCE_PREF > $cpu/cpufreq/energy_performance_preference || return 1
			done
		fi

	fi

	# Set cpu scaling at boot (ie set pstate status to active/passive at boot)
	if [ -n "$INTEL_PSTATE_STATUS"  ]; then
		echo $INTEL_PSTATE_STATUS > /sys/devices/system/cpu/intel_pstate/status
	else
		echo passive > /sys/devices/system/cpu/intel_pstate/status
	fi

	# enable sdcardfs if /data is not mounted on tmpfs or 9p
	#mount | grep /data\ | grep -qE 'tmpfs|9p'
	#[ $? -eq 0 ] && set_prop_if_empty ro.sys.sdcardfs false

	# remove wl if it's not used
	local wifi
	if [ -d /sys/class/net/wlan0 ]; then
		wifi=$(basename `readlink /sys/class/net/wlan0/device/driver`)
		[ "$wifi" != "wl" ] && rmmod_if_exist wl
	fi

	# disable virt_wifi by default, only turn on when user set VIRT_WIFI=1
	local eth=`getprop net.virt_wifi eth0`
	if [ -d /sys/class/net/$eth -a "$VIRT_WIFI" -gt "0" ]; then
		if [ -n "$wifi" -a "$VIRT_WIFI" -ge "1" ]; then
			rmmod_if_exist iwlmvm $wifi
		fi
		if [ ! -d /sys/class/net/wlan0 ]; then
			ifconfig $eth down
			ip link set $eth name wifi_eth
			ifconfig wifi_eth up
			ip link add link wifi_eth name wlan0 type virt_wifi
		fi
	fi

}

function init_hal_audio()
{
	## HACK: if snd_hda_intel cannot be probed, reprobe it
	if [ "$( lsmod | grep "snd_hda_intel" )" ]; then	
		if [ "$( dmesg | grep "couldn't bind with audio component" )" ]; then
		rmmod snd_hda_intel
		modprobe snd_hda_intel
		fi
	fi

	case "$PRODUCT" in
		VirtualBox*|Bochs*)
			[ -d /proc/asound/card0 ] || modprobe snd-sb16 isapnp=0 irq=5
			;;
		TS10*)
			set_prop_if_empty hal.audio.out pcmC0D2p
			;;
	esac

	case "$(ls /proc/asound)" in
		*sofhdadsp*)
			AUDIO_PRIMARY=x86_celadon
			;;
	esac
	set_property ro.hardware.audio.primary ${AUDIO_PRIMARY:-x86}

	if [ "$BOARD" == "Jupiter" ] && [ "$VENDOR" == "Valve" ]
	then
		pcm_card=$(cat /proc/asound/cards | grep acp5x | awk '{print $1}')
		# headset microphone on d0, 32bit only
		set_property hal.audio.in.headset "pcmC${pcm_card}D0c"
		set_property hal.audio.in.headset.format 1

		# internal microphone on d0, 32bit only
		set_property hal.audio.in.mic "pcmC${pcm_card}D0c"
		set_property hal.audio.in.mic.format 1

		# headphone jack on d0, 32bit only
		set_property hal.audio.out.headphone "pcmC${pcm_card}D0p"
		set_property hal.audio.out.headphone.format 1

		# speaker on d1, 16bit only
		set_property hal.audio.out.speaker "pcmC${pcm_card}D1p"
		set_property hal.audio.out.speaker.format 0

		# enable hdmi audio on the 3rd output, but it really depends on how docks wire things
		# to make matters worse, jack detection on alsa does not seem to always work on my setup, so a dedicated hdmi hal might want to send data to all ports instead of just probing
		pcm_card=$(cat /proc/asound/cards | grep HDA-Intel | awk '{print $1}')
		set_property hal.audio.out.hdmi "pcmC${pcm_card}D8p"
	fi
}

function init_hal_audio_bootcomplete()
{
	if [ "$BOARD" == "Jupiter" ] && [ "$VENDOR" == "Valve" ]
	then
		alsaucm -c Valve-Jupiter-1 set _verb HiFi

		pcm_card=$(cat /proc/asound/cards | grep acp5x | awk '{print $1}')
		# headset microphone on d0, 32bit only
		amixer -c ${pcm_card} sset 'Headset Mic',0 on

		# internal microphone on d0, 32bit only
		amixer -c ${pcm_card} sset 'Int Mic',0 on
		amixer -c ${pcm_card} sset 'DMIC Enable',0 on

		# headphone jack on d0, 32bit only
		amixer -c ${pcm_card} sset 'Headphone',0 on

		# speaker on d1, 16bit only
		amixer -c ${pcm_card} sset 'Left DSP RX1 Source',0 ASPRX1
		amixer -c ${pcm_card} sset 'Right DSP RX1 Source',0 ASPRX2
		amixer -c ${pcm_card} sset 'Left DSP RX2 Source',0 ASPRX1
		amixer -c ${pcm_card} sset 'Right DSP RX2 Source',0 ASPRX2
		amixer -c ${pcm_card} sset 'Left DSP1 Preload',0 on
		amixer -c ${pcm_card} sset 'Right DSP1 Preload',0 on

		# unmute them all
		amixer -c ${pcm_card} sset 'IEC958',0 on
		amixer -c ${pcm_card} sset 'IEC958',1 on
		amixer -c ${pcm_card} sset 'IEC958',2 on
		amixer -c ${pcm_card} sset 'IEC958',3 on
	fi

#	[ -d /proc/asound/card0 ] || modprobe snd-dummy
	for c in $(grep '\[.*\]' /proc/asound/cards | awk '{print $1}'); do
		f=/system/etc/alsa/$(cat /proc/asound/card$c/id).state
		if [ -e $f ]; then
			alsa_ctl -f $f restore $c
		else
			alsa_ctl init $c
			alsa_amixer -c $c set Master on
			alsa_amixer -c $c set Master 100%
			alsa_amixer -c $c set Headphone on
			alsa_amixer -c $c set Headphone 100%
			alsa_amixer -c $c set Speaker on
			alsa_amixer -c $c set Speaker 100%
			alsa_amixer -c $c set Capture 80%
			alsa_amixer -c $c set Capture cap
			alsa_amixer -c $c set PCM 100% unmute
			alsa_amixer -c $c set SPO unmute
			alsa_amixer -c $c set IEC958 on
			alsa_amixer -c $c set 'Mic Boost' 1
			alsa_amixer -c $c set 'Internal Mic Boost' 1
		fi
		d=/data/vendor/alsa/$(cat /proc/asound/card$c/id).state
		if [ -e $d ]; then
			alsa_ctl -f $d restore $c
		fi
	done
}

function init_bcm_wireless()
{
	# Inspired from PhoenixOS bcm wireless init
	local BCMAID=$(lspci | grep "14e4" | awk '{print $4}' | cut -d':' -f2)

	case "${BCMAID}" in
		4311|4312|4315|4727|4328|4329|432a|432b|432c|432d|0576|4353|4357|4358|4359|4365|4331|43b1|43a0|4360 )
			lsmod | grep "b43\|b44\|b43legacy\|ssb\|bcma\|brcm80211\|wl" && {
				rmmod b43 b44 b43legacy ssb bcma brcm80211 wl
				modprobe wl
			}
			;;
		*)
			;;
	esac
	BCMVRAM=$(ls /sys/firmware/efi/efivars | grep nvram)
	BCMSDIO=$(dmesg | grep brcmfmac | grep txt)
	if [ -n "$BCMSDIO" ]; then 
		BCMNAME=$(echo $BCMSDIO | awk '{print $9}')
		mount -t efivarfs none /sys/firmware/efi/efivars
		cp /sys/firmware/efi/efivars/nvram-74b00bd9-805a-4d61-b51f-43268123d113 /lib/firmware/$BCMNAME
		set_property bliss.brcmfmac 1
	fi
}

function init_hal_bluetooth()
{
	for r in /sys/class/rfkill/*; do
		type=$(cat $r/type)
		[ "$type" = "wlan" -o "$type" = "bluetooth" ] && echo 1 > $r/state
	done

	case "$PRODUCT" in
		T100TAF)
			set_property bluetooth.interface hci1
			;;
		T10*TA|M80TA|HP*Omni*)
			BTUART_PORT=/dev/ttyS1
			set_property hal.bluetooth.uart.proto bcm
			;;
		MacBookPro8*)
			rmmod b43
			modprobe b43 btcoex=0
			modprobe btusb
			;;
		# FIXME
		# Fix MacBook 2013-2015 (Air6/7&Pro11/12) BCM4360 ssb&wl conflict.
		MacBookPro11* | MacBookPro12* | MacBookAir6* | MacBookAir7*)
			rmmod b43
			rmmod ssb
			rmmod bcma
			rmmod wl
			modprobe wl
			modprobe btusb
			;;
		*)
			for bt in $(toybox lsusb -v | awk ' /Class:.E0/ { print $9 } '); do
				chown 1002.1002 $bt && chmod 660 $bt
			done
			;;
	esac

	if [ -n "$BTUART_PORT" ]; then
		set_property hal.bluetooth.uart $BTUART_PORT
		chown bluetooth.bluetooth $BTUART_PORT
		start btattach
	fi

	if [ "$BTLINUX_HAL" = "1" ]; then
		start btlinux-1.1
	else
		start vendor.bluetooth-1-1
	fi
}

function init_hal_camera()
{
	case "$UEVENT" in
		*e-tabPro*)
			set_prop_if_empty hal.camera.0 0,270
			set_prop_if_empty hal.camera.2 1,90
			;;
		*LenovoideapadD330*)
			set_prop_if_empty hal.camera.0 0,90
			set_prop_if_empty hal.camera.2 1,90
			;;
		*)
			;;
	esac
}

function init_hal_gps()
{
	# TODO
	return
}

function set_drm_mode()
{
	case "$PRODUCT" in
		ET1602*)
			drm_mode=1366x768
			;;
		*)
			[ -n "$video" ] && drm_mode=$video
			;;
	esac

	[ -n "$drm_mode" ] && set_property debug.drm.mode.force $drm_mode
}

function init_uvesafb()
{
	UVESA_MODE=${UVESA_MODE:-${video%@*}}

	case "$PRODUCT" in
		ET2002*)
			UVESA_MODE=${UVESA_MODE:-1600x900}
			;;
		*)
			;;
	esac

	modprobe uvesafb mode_option=${UVESA_MODE:-1024x768}-32 ${UVESA_OPTION:-mtrr=3 scroll=redraw} v86d=/system/bin/v86d
}

function init_hal_gralloc()
{
	case "$(readlink /sys/class/graphics/fb0/device/driver)" in
		*virtio_gpu|*virtio-pci)
			HWC=${HWC:-drm_minigbm_celadon}
			GRALLOC=${GRALLOC:-minigbm_arcvm}
			#video=${video:-1280x768}
			;&
		*nouveau)
			GRALLOC=${GRALLOC:-gbm_hack}
			HWC=${HWC:-drm_celadon}
			;&
		*i915)
			if [ "$(cat /sys/kernel/debug/dri/0/i915_capabilities | grep -e 'gen' -e 'graphics version' | awk '{print $NF}')" -gt 9 ]; then
				HWC=${HWC:-drm_minigbm_celadon}
				GRALLOC=${GRALLOC:-minigbm}
			fi
			;&
		*amdgpu)
			HWC=${HWC:-drm_minigbm_celadon}
			GRALLOC=${GRALLOC:-minigbm}
			;&
		*radeon|*vmwgfx*)
			if [ "$HWACCEL" != "0" ]; then
				${HWC:+set_property ro.hardware.hwcomposer $HWC}
				set_property ro.hardware.gralloc ${GRALLOC:-gbm}
				set_drm_mode
			fi
			;;
		"")
			init_uvesafb
			;&
		*)
			export HWACCEL=0
			;;
	esac

	if [ "$GRALLOC4_MINIGBM" = "1" ]; then
		set_property debug.ui.default_mapper 4
		set_property debug.ui.default_gralloc 4
		case "$GRALLOC" in
			minigbm)
				start vendor.graphics.allocator-4-0
			;;
			minigbm_arcvm)
				start vendor.graphics.allocator-4-0-arcvm
			;;
			minigbm_gbm_mesa)
				start vendor.graphics.allocator-4-0-gbm_mesa
			;;
			*)
			;;
		esac
	else
		set_property debug.ui.default_mapper 2
		set_property debug.ui.default_gralloc 2
		start vendor.gralloc-2-0
	fi

	[ -n "$DEBUG" ] && set_property debug.egl.trace error
}

function init_egl()
{

	if [ "$HWACCEL" != "0" ]; then
		if [ "$ANGLE" == "1" ]; then
			set_property ro.hardware.egl angle
		else
			set_property ro.hardware.egl mesa
		fi
	else
		if [ "$ANGLE" == "1" ]; then
			set_property ro.hardware.egl angle
		else
			set_property ro.hardware.egl swiftshader
		fi
		set_property ro.hardware.vulkan pastel
		start vendor.hwcomposer-2-1
	fi

	# Set OpenGLES version
	case "$FORCE_GLES" in
        *3.0*)
    	    set_property ro.opengles.version 196608
            export MESA_GLES_VERSION_OVERRIDE=3.0
		;;
		*3.1*)
    		set_property ro.opengles.version 196609
			export MESA_GLES_VERSION_OVERRIDE=3.1
		;;
		*3.2*)
    		set_property ro.opengles.version 196610
			export MESA_GLES_VERSION_OVERRIDE=3.2
		;;
		*)
    		set_property ro.opengles.version 196608
		;;
	esac

	# Set RenderEngine backend
	if [ -z ${FORCE_RENDERENGINE+x} ]; then
		set_property debug.renderengine.backend threaded
	else
		set_property debug.renderengine.backend $FORCE_RENDERENGINE
	fi

	# Set default GPU render
	if [ -z ${GPU_OVERRIDE+x} ]; then
		echo ""
	else
		set_property gralloc.gbm.device /dev/dri/$GPU_OVERRIDE
		set_property vendor.hwc.drm.device /dev/dri/$GPU_OVERRIDE
		set_property hwc.drm.device /dev/dri/$GPU_OVERRIDE
	fi

}

function init_hal_hwcomposer()
{
	# TODO
	if [ "$HWACCEL" != "0" ]; then
		if [ "$HWC" = "default" ]; then
			if [ "$HWC_IS_DRMFB" = "1" ]; then
				set_property debug.sf.hwc_service_name drmfb
				start vendor.hwcomposer-2-1.drmfb
			else
				set_property debug.sf.hwc_service_name default
				start vendor.hwcomposer-2-1
			fi
		else
			set_property debug.sf.hwc_service_name default
			start vendor.hwcomposer-2-4

			if [[ "$HWC" == "drm_celadon" || "$HWC" == "drm_minigbm_celadon" ]]; then
				set_property vendor.hwcomposer.planes.enabling $MULTI_PLANE
				set_property vendor.hwcomposer.planes.num $MULTI_PLANE_NUM
				set_property vendor.hwcomposer.preferred.mode.limit $HWC_PREFER_MODE
				set_property vendor.hwcomposer.connector.id $CONNECTOR_ID
				set_property vendor.hwcomposer.mode.id $MODE_ID
				set_property vendor.hwcomposer.connector.multi_refresh_rate $MULTI_REFRESH_RATE
			fi
		fi
	fi
}

function init_hal_media()
{
	# Check if we want to use codec2
	if [ -z ${CODEC2_LEVEL+x} ]; then
		echo ""
	else
		set_property debug.stagefright.ccodec $CODEC2_LEVEL
	fi

	# Disable YUV420 planar on OMX codecs
	if [ "$OMX_NO_YUV420" -ge "1" ]; then
		set_property ro.yuv420.disable true
	else
		set_property ro.yuv420.disable false
	fi

	if [ "$BOARD" == "Jupiter" ] && [ "$VENDOR" == "Valve" ]
	then
		FFMPEG_CODEC2_PREFER=${FFMPEG_CODEC2_PREFER:-1}
	fi

#FFMPEG Codec Setup
## Turn on/off FFMPEG OMX by default
	if [ "$FFMPEG_OMX_CODEC" -ge "1" ]; then
	    set_property media.sf.omx-plugin libffmpeg_omx.so
    	set_property media.sf.extractor-plugin libffmpeg_extractor.so
	else
	    set_property media.sf.omx-plugin ""
    	set_property media.sf.extractor-plugin ""
	    set_property debug.ffmpeg-omx.disable 1
	fi

## Enable logging
    if [ "$FFMPEG_CODEC_LOG" -ge "1" ]; then
        set_property debug.ffmpeg.loglevel verbose
    fi	
## Disable HWAccel (currently only VA-API) and use software rendering
    if [ "$FFMPEG_HWACCEL_DISABLE" -ge "1" ]; then
        set_property media.sf.hwaccel 0
    else
        set_property media.sf.hwaccel 1
    fi
## Put c2.ffmpeg to the highest rank amongst the media codecs
    if [ "$FFMPEG_CODEC2_PREFER" -ge "1" ]; then
        set_property debug.ffmpeg-codec2.rank 0
    else
        set_property debug.ffmpeg-codec2.rank 4294967295
    fi
## FFMPEG deinterlace, we will put both software mode and VA-API one here
	if [ -z "${FFMPEG_CODEC2_DEINTERLACE+x}" ]; then
		echo ""
	else
		set_property debug.ffmpeg-codec2.deinterlace $FFMPEG_CODEC2_DEINTERLACE
	fi
	if [ -z "${FFMPEG_CODEC2_DEINTERLACE_VAAPI+x}" ]; then
		echo ""
	else
		set_property debug.ffmpeg-codec2.deinterlace.vaapi $FFMPEG_CODEC2_DEINTERLACE_VAAPI
	fi
## Handle DRM prime on ffmpeg codecs, we will disable by default due to 
## the fact that it doesn't work with gbm_gralloc yet
	if [ "$FFMPEG_CODEC2_DRM" -ge "1" ]; then
	    set_property debug.ffmpeg-codec2.hwaccel.drm 1
	else
	    set_property debug.ffmpeg-codec2.hwaccel.drm 0
	fi

}

function init_hal_vulkan()
{
	case "$(readlink /sys/class/graphics/fb0/device/driver)" in
		*i915)
			if [ "$(cat /sys/kernel/debug/dri/0/i915_capabilities | grep -e 'gen' -e 'graphics version' | awk '{print $NF}')" -lt 9 ]; then
				set_property ro.hardware.vulkan intel_hasvk
			else
				set_property ro.hardware.vulkan intel
			fi
			;;
		*amdgpu)
			set_property ro.hardware.vulkan amd
			;;
		*virtio_gpu|*virtio-pci)
			set_property ro.hardware.vulkan virtio
			;;
		*)
			set_property ro.hardware.vulkan pastel
			;;
	esac
}

function init_hal_lights()
{
	chown 1000.1000 /sys/class/backlight/*/brightness
}

function init_hal_power()
{
	for p in /sys/class/rtc/*; do
		echo disabled > $p/device/power/wakeup
	done

	# TODO
	case "$PRODUCT" in
		HP*Omni*|OEMB|Standard*PC*|Surface*3|T10*TA|VMware*)
			SLEEP_STATE=none
			;;
		e-tab*Pro)
			SLEEP_STATE=force
			;;
		*TAIFAElimuTab*)
			setprop sleep.earlysuspend 1
			;;
		*)
			;;
	esac

	# Detect is deep sleep is supported and auto set sleep.state parameter
	mem_sleep_default=$(cat /sys/power/mem_sleep)
	if [[ "$mem_sleep_default" == *deep* ]]; then
		setprop sleep.state ${SLEEP_STATE:-mem}
	else
		setprop sleep.state ${SLEEP_STATE:-freeze}
	fi

	current_sleep_state=$(getprop sleep.state)
	if [ "${current_sleep_state}" = "mem" ]; then
		echo "deep" > /sys/power/mem_sleep
	fi
}

function init_hal_thermal()
{
	#thermal-daemon test, pulled from Project Celadon
	case "$(cat /sys/class/dmi/id/chassis_vendor | head -1)" in 
	QEMU)
		setprop vendor.thermal.enable 0
		;;
	*)
		setprop vendor.thermal.enable 1
		;;
	esac
}

function init_hal_sensors()
{
    if [ "$SENSORS_FORCE_KBDSENSOR" == "1" ]; then
        # Option to force kbd sensor
        hal_sensors=kbd
        has_sensors=true
    else
        # if we have sensor module for our hardware, use it
        ro_hardware=$(getprop ro.hardware)
        [ -f /system/lib/hw/sensors.${ro_hardware}.so ] && return 0

        local hal_sensors=kbd
        local has_sensors=true
        case "$UEVENT" in
            *MS-N0E1*)
                set_property ro.ignore_atkbd 1
                set_property poweroff.doubleclick 0
                setkeycodes 0xa5 125
                setkeycodes 0xa7 1
                setkeycodes 0xe3 142
                ;;
            *Aspire1*25*)
                modprobe lis3lv02d_i2c
                echo -n "enabled" > /sys/class/thermal/thermal_zone0/mode
                ;;
            *Aspire*SW5-012*)
                set_property ro.iio.accel.order 102
                ;;
            *LenovoideapadD330*)
                set_property ro.iio.accel.order 102
                set_property ro.ignore_atkbd 1
                ;&
            *LINX1010B*)
                set_property ro.iio.accel.x.opt_scale -1
                set_property ro.iio.accel.z.opt_scale -1
                ;;
            *i7Stylus*|*M80TA*)
                set_property ro.iio.accel.x.opt_scale -1
                ;;
            *LenovoMIIX320*|*ONDATablet*)
                set_property ro.iio.accel.order 102
                set_property ro.iio.accel.x.opt_scale -1
                set_property ro.iio.accel.y.opt_scale -1
                ;;
            *Venue*8*Pro*3845*)
                set_property ro.iio.accel.order 102
                ;;
            *ST70416-6*)
                set_property ro.iio.accel.order 102
                ;;
            *T*0*TA*|*M80TA*)
                set_property ro.iio.accel.y.opt_scale -1
                ;;
			*Akoya*P2213T*)
				set_property ro.iio.accel.order 102
				;;
            *TECLAST*X4*|*SF133AYR110*)
                set_property ro.iio.accel.order 102
                set_property ro.iio.accel.x.opt_scale -1
                set_property ro.iio.accel.y.opt_scale -1
                ;;
			*TAIFAElimuTab*)
				set_property ro.ignore_atkbd 1
				set_property ro.iio.accel.quirks no-trig
				set_property ro.iio.accel.order 102
				;;
            *SwitchSA5-271*|*SwitchSA5-271P*)
                set_property ro.ignore_atkbd 1
                has_sensors=true
                hal_sensors=iio
                ;&
            *)
                has_sensors=false
                ;;
        esac

            # has iio sensor-hub?
            if [ -n "`ls /sys/bus/iio/devices/iio:device* 2> /dev/null`" ]; then
                toybox chown -R 1000.1000 /sys/bus/iio/devices/iio:device*/
                [ -n "`ls /sys/bus/iio/devices/iio:device*/in_accel_x_raw 2> /dev/null`" ] && has_sensors=true
                hal_sensors=iio
            elif [ "$hal_sensors" != "kbd" ] | [ hal_sensors=iio ]; then
                has_sensors=true
            fi

            # is steam deck?
            if [ "$BOARD" == "Jupiter" ] && [ "$VENDOR" == "Valve" ]
            then
                set_property poweroff.disable_virtual_power_button 1
                hal_sensors=jupiter
                has_sensors=true
            fi
    fi


	for c in `cat /proc/cmdline`; do
		case $c in
			*=*)
				eval $c
				if [ -z "$1" ]; then
					case $c in
						SET_HDMI_ROTATION=*)
							# Set HDMI rotation (portrait, landscape)
							set_property persist.demo.hdmirotation "$SET_HDMI_ROTATION"
							;;
						SET_PER_WINDOW_INPUT_ROTATION=*)
							# Set per window input rotation on/off (true, false)
							set_property persist.debug.per_window_input_rotation "$SET_PER_WINDOW_INPUT_ROTATION"
							;;
						SET_SF_ROTATION=*)
							set_property ro.sf.hwrotation "$SET_SF_ROTATION"
							;;
						SET_SF_SWROTATION=*)
							set_property ro.sf.swrotation "$SET_SF_SWROTATION"
							;;
						SET_TOUCHSCREEN_ROTATION=*)
							# property: ro.boot.hwrotation has four cases:
							# 0, 90, 180, 270
							#
							# This property will also trigger SET_PRIMARY_DISPLAY_ORIENTATION
							# / ro.surface_flinger.primary_display_orientation
							set_property ro.boot.hwrotation "$SET_TOUCHSCREEN_ROTATION"
							;;
						SET_ROTATION_ON_INTERNAL_DISPLAY=*)
							# property: ro.boot.android.force_rotation_on_internal_displays has four cases:
							# 0, 90, 180, 270
							set_property ro.boot.android.force_rotation_on_internal_displays "$SET_ROTATION_ON_INTERNAL_DISPLAY"
							;;
						SET_OVERRIDE_FORCED_ORIENT=*)
							set_property config.override_forced_orient "$SET_OVERRIDE_FORCED_ORIENT"
							;;
						SET_SYS_APP_ROTATION=*)
							# property: persist.sys.app.rotation has three cases:
							# 1.force_land: always show with landscape, if a portrait apk, system will scale up it
							# 2.middle_port: if a portrait apk, will show in the middle of the screen, left and right will show black
							# 3.original: original orientation, if a portrait apk, will rotate 270 degree
							set_property persist.sys.app.rotation "$SET_SYS_APP_ROTATION"
							;;
						SET_PRIMARY_DISPLAY_ORIENTATION=*)
							# property: ro.surface_flinger.primary_display_orientation has three cases:
							# ORIENTATION_0, ORIENTATION_90, ORIENTATION_180, ORIENTATION_270
							set_property ro.surface_flinger.primary_display_orientation "$SET_PRIMARY_DISPLAY_ORIENTATION"
							;;
						SET_HDMIROTATION=*)
							# Set HDMI rotation
							# options: portrait, landscape
							set_property persist.demo.hdmirotation "$SET_HDMIROTATION"
							;;
						SET_HDMIROTATIONLOCK=*)
							# Set HDMI rotation lock
							# options: true or false
							set_property persist.demo.hdmirotationlock "$SET_HDMIROTATIONLOCK"
							;;
						SET_SINGLEDISPLAY=*)
							# Set single display
							# options: true or false
							set_property persist.demo.singledisplay "$SET_SINGLEDISPLAY"
							;;
					esac
				fi
				;;
		esac
	done

					

    set_property ro.iio.accel.quirks "no-trig,no-event"
    set_property ro.iio.anglvel.quirks "no-trig,no-event"
    set_property ro.iio.magn.quirks "no-trig,no-event"
    set_property ro.hardware.sensors $hal_sensors
    set_property config.override_forced_orient ${HAS_SENSORS:-$has_sensors}
}

function init_hal_surface()
{
	case "$UEVENT" in
		*Surface*Pro*[4-9]*|*Surface*Book*|*Surface*Laptop*[1~4]*|*Surface*Laptop*Studio*)
			start iptsd_runner
			;;
	esac
}

function create_pointercal()
{
	if [ ! -e /data/misc/tscal/pointercal ]; then
		mkdir -p /data/misc/tscal
		touch /data/misc/tscal/pointercal
		chown 1000.1000 /data/misc/tscal /data/misc/tscal/*
		chmod 775 /data/misc/tscal
		chmod 664 /data/misc/tscal/pointercal
	fi
}

function init_tscal()
{
	case "$UEVENT" in
		*ST70416-6*)
			modprobe gslx680_ts_acpi
			;&
		*T91*|*T101*|*ET2002*|*74499FU*|*945GSE-ITE8712*|*CF-19[CDYFGKLP]*|*TECLAST:rntPAD*)
			create_pointercal
			return
			;;
		*)
			;;
	esac

	for usbts in $(lsusb | awk '{ print $6 }'); do
		case "$usbts" in
			0596:0001|0eef:0001|14e1:6000|14e1:5000)
				create_pointercal
				return
				;;
			*)
				;;
		esac
	done
}

function init_ril()
{
	case "$UEVENT" in
		*TEGA*|*2010:svnIntel:*|*Lucid-MWE*)
			set_property rild.libpath /system/lib/libhuaweigeneric-ril.so
			set_property rild.libargs "-d /dev/ttyUSB2 -v /dev/ttyUSB1"
			set_property ro.radio.noril no
			;;
		*)
			set_property ro.radio.noril yes
			;;
	esac
}

function init_cpu_governor()
{
	governor=$(getprop cpu.governor)

	[ $governor ] && {
		for cpu in $(ls -d /sys/devices/system/cpu/cpu?); do
			echo $governor > $cpu/cpufreq/scaling_governor || return 1
		done
	}
}

function set_lowmem()
{
	# 3GB size in kB : https://source.android.com/devices/tech/perf/low-ram
	SIZE_3GB=3145728

	mem_size=`cat /proc/meminfo | grep MemTotal | tr -s ' ' | cut -d ' ' -f 2`

	if [ "$mem_size" -le "$SIZE_3GB" ]
	then
		setprop ro.config.low_ram ${FORCE_LOW_MEM:-true}
	else
		# Choose between low-memory vs high-performance device. 
		# Default = false.
		setprop ro.config.low_ram ${FORCE_LOW_MEM:-false}
	fi

	# Use free memory and file cache thresholds for making decisions 
	# when to kill. This mode works the same way kernel lowmemorykiller 
	# driver used to work. AOSP Default = false, Our default = true
	setprop ro.lmk.use_minfree_levels ${FORCE_MINFREE_LEVELS:-true}
	
}

function set_custom_ota()
{
	for c in `cat /proc/cmdline`; do
		case $c in
			*=*)
				eval $c
				if [ -z "$1" ]; then
					case $c in
						# Set TimeZone
						SET_CUSTOM_OTA_URI=*)
							setprop bliss.updater.uri "$SET_CUSTOM_OTA_URI"
							;;
					esac
				fi
				;;
		esac
	done
	
}

function init_loop_links()
{
	mkdir -p /dev/block/by-name
	for part in kernel initrd system; do
		for suffix in _a _b; do
			loop_device=$(losetup -a | grep "$part$suffix" | cut -d ":" -f1)
			if [ ! -z "$loop_device" ]; then
				ln -s $loop_device /dev/block/by-name/$part$suffix
			fi
		done
	done
	loop_device=$(losetup -a | grep misc | cut -d ":" -f1)
	ln -s $loop_device /dev/block/by-name/misc

	ln -s /dev/block/by-name/kernel_a /dev/block/by-name/boot_a
	ln -s /dev/block/by-name/kernel_b /dev/block/by-name/boot_b
}

function init_prepare_ota()
{
	# If there's slot set, turn on bootctrl
	# If not, disable the OTA app (in bootcomplete)
	if [ "$(getprop ro.boot.slot_suffix)" ]; then
		start vendor.boot-hal-1-2
	fi
}


function set_custom_timezone()
{
	for c in `cat /proc/cmdline`; do
		case $c in
			*=*)
				eval $c
				if [ -z "$1" ]; then
					case $c in
						# Set TimeZone
						SET_TZ_LOCATION=*)
							settings put global time_zone "$SET_TZ_LOCATION"
							setprop persist.sys.timezone "$SET_TZ_LOCATION"
							;;
					esac
				fi
				;;
		esac
	done
	
}

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
		settings put global force_desktop_mode_on_external_displays "$FORCE_DESKTOP_ON_EXTERNAL"
	fi

	# ZQYMultiClientIME
	exists_zqymcime=$(pm list packages com.zqy.multidisplayinput | grep -c com.zqy.multidisplayinput)
	if [ $exists_zqymcime -eq 1 ]; then
		# Enable desktop mode on external display (required for MultiDisplay Input)
		settings put global force_desktop_mode_on_external_displays "$FORCE_DESKTOP_ON_EXTERNAL"
	fi

	# ccom.example.screenoverlay
	exists_screenview=$(pm list com.example.screenoverlay | grep -c com.example.screenoverlay)
	if [ $exists_screenview -eq 1 ]; then
		appops set com.example.screenoverlay PROJECT_MEDIA allow
		pm grant com.example.screenoverlay android.permission.MANAGE_MEDIA_PROJECTION
		appops set com.example.screenoverlay MANAGE_MEDIA_PROJECTION allow
		pm grant com.example.screenoverlay android.permission.ACCESS_SURFACE_FLINGER
		pm grant com.example.screenoverlay android.permission.CAPTURE_SECURE_VIDEO_OUTPUT
		pm grant com.example.screenoverlay android.permission.SYSTEM_ALERT_WINDOW
		pm grant com.example.screenoverlay android.permission.INJECT_EVENTS
		appops set com.example.screenoverlay INJECT_EVENTS allow
	fi

	# com.bliss.bootsight
	exists_bootsight=$(pm list packages com.bliss.bootsight | grep -c com.bliss.bootsight)
	if [ $exists_bootsight -eq 1 ]; then
		if [ ! -f /data/misc/bootsight/default ]; then
			dpm set-active-admin com.bliss.bootsight/android.app.admin.DeviceAdminReceiver
			appops set com.bliss.bootsight REQUEST_IGNORE_BATTERY_OPTIMIZATIONS allow
			pm grant com.bliss.bootsight android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
			pm grant com.bliss.bootsight android.permission.ACCESS_NETWORK_STATE
			pm grant com.bliss.bootsight android.permission.INTERNET
			pm grant com.bliss.bootsight android.permission.SYSTEM_ALERT_WINDOW
			pm grant com.bliss.bootsight android.permission.RECEIVE_BOOT_COMPLETED
			dumpsys deviceidle whitelist +com.bliss.bootsight
			# Set config marker
			mkdir -p /data/misc/bootsight
			touch /data/misc/bootsight/default
			chown 1000.1000 /data/misc/bootsight /data/misc/bootsight/*
			chmod 775 /data/misc/bootsight
			chmod 664 /data/misc/bootsight/default
		fi
	fi

	# GBoard 
	exists_gboard=$(pm list packages com.google.android.inputmethod.latin | grep -c com.google.android.inputmethod.latin)
	if [ $exists_gboard -eq 1 ]; then
		if [ ! -f /data/misc/gboard/default ]; then
			# set default input method
			ime enable com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME
			ime set com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME
			# Set config marker
			mkdir -p /data/misc/gboard
			touch /data/misc/gboard/default
			chown 1000.1000 /data/misc/gboard /data/misc/gboard/*
			chmod 775 /data/misc/gboard
			chmod 664 /data/misc/gboard/default
		fi
	fi

	# Vapor Launcher
	exists_vaporlauncher=$(pm list packages org.vapor.android | grep -c org.vapor.android)
	if [ $exists_vaporlauncher -eq 1 ]; then
		if [ ! -f /data/misc/vlconfig/config ]; then
			# set device config
			mkdir -p /data/misc/vlconfig
			touch /data/misc/vlconfig/config
			chown 1000.1000 /data/misc/vlconfig /data/misc/vlconfig/*
			chmod 775 /data/misc/vlconfig
			chmod 664 /data/misc/vlconfig/config

			pm set-home-activity "org.vapor.android/.AppWorker"
			am start -a android.intent.action.MAIN -c android.intent.category.HOME
		fi
	fi

	# Daijishou Launcher
	exists_dslauncher=$(pm list packages com.magneticchen.daijishou | grep -c com.magneticchen.daijishou)
	if [ $exists_dslauncher -eq 1 ]; then
		if [ ! -f /data/misc/dlconfig/config ]; then
			# set device config
			mkdir -p /data/misc/dlconfig
			touch /data/misc/dlconfig/config
			chown 1000.1000 /data/misc/dlconfig /data/misc/dlconfig/*
			chmod 775 /data/misc/dlconfig
			chmod 664 /data/misc/dlconfig/config

			pm set-home-activity "com.magneticchen.daijishou/.activities.BootstrapActivity"
			am start -a android.intent.action.MAIN -c android.intent.category.HOME
		fi
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

		# set overlays enabled
		settings put secure secure_overlay_settings 1

		# allow displaying over other apps if in Go mode
		settings put system alert_window_bypass_low_ram 1
				
		pm grant com.bliss.restrictedlauncher android.permission.SYSTEM_ALERT_WINDOW
		pm set-home-activity "com.bliss.restrictedlauncher/.activities.LauncherActivity"
		am start -a android.intent.action.MAIN -c android.intent.category.HOME
	fi

	# BlissRestrictedLauncherPro
	exists_restlauncherpro=$(pm list packages com.bliss.restrictedlauncher.pro | grep -c com.bliss.restrictedlauncher.pro)
	if [ $exists_restlauncherpro -eq 1 ]; then
		if [ ! -f /data/misc/rlpconfig/admin ]; then
			# set device admin
			dpm set-device-owner com.bliss.restrictedlauncher.pro/com.bliss.restrictedlauncher.DeviceAdmin
			mkdir -p /data/misc/rlconfig
			touch /data/misc/rlconfig/admin
			chown 1000.1000 /data/misc/rlconfig /data/misc/rlconfig/*
			chmod 775 /data/misc/rlconfig
			chmod 664 /data/misc/rlconfig/admin
		fi

		# set overlays enabled
		settings put secure secure_overlay_settings 1

		# allow displaying over other apps if in Go mode
		settings put system alert_window_bypass_low_ram 1
				
		pm grant com.bliss.restrictedlauncher.pro android.permission.SYSTEM_ALERT_WINDOW
		pm set-home-activity "com.bliss.restrictedlauncher.pro/com.bliss.restrictedlauncher.activities.LauncherActivity"
		am start -a android.intent.action.MAIN -c android.intent.category.HOME

		if [ -f /data/data/com.bliss.restrictedlauncher.pro/files/whitelist.lst ]; then
			if [ ! -f /data/misc/rlpconfig/whitelist ]; then
				echo -e "\ncom.android.printservice.recommendation" >> /data/data/com.bliss.restrictedlauncher.pro/files/whitelist.lst
				echo -e "com.android.printspooler" >> /data/data/com.bliss.restrictedlauncher.pro/files/whitelist.lst
				echo -e "com.android.systemui" >> /data/data/com.bliss.restrictedlauncher.pro/files/whitelist.lst
				echo -e "com.android.packageinstaller" >> /data/data/com.bliss.restrictedlauncher.pro/files/whitelist.lst				
				mkdir -p /data/misc/rlconfig
				touch /data/misc/rlconfig/whitelist
				chown 1000.1000 /data/misc/rlconfig /data/misc/rlconfig/*
				chmod 775 /data/misc/rlconfig
				chmod 664 /data/misc/rlconfig/whitelist
			fi
		fi
	fi

	# Molla Launcher
	exists_molla=$(pm list packages com.sinu.molla | grep -c com.sinu.molla)
	if [ $exists_molla -eq 1 ]; then
		pm set-home-activity "com.sinu.molla/.MainActivity"
		am start -a android.intent.action.MAIN -c android.intent.category.HOME
	fi

	# CrossLauncher
	exists_cross=$(pm list packages id.psw.vshlauncher | grep -c id.psw.vshlauncher)
	if [ $exists_cross -eq 1 ]; then
		pm set-home-activity "id.psw.vshlauncher/.activities.Xmb"
		am start -a android.intent.action.MAIN -c android.intent.category.HOME
	fi

	# TV-Mode Launcher
	exists_tvl=$(pm list packages nl.ndat.tvlauncher | grep -c nl.ndat.tvlauncher)
	if [ $exists_tvl -eq 1 ]; then
		pm set-home-activity "nl.ndat.tvlauncher/.MainActivity"
		am start -a android.intent.action.MAIN -c android.intent.category.HOME
	fi

	# Titanius Launcher
	exists_titanius=$(pm list packages app.titanius.launcher | grep -c app.titanius.launcher)
	if [ $exists_titanius -eq 1 ]; then
		pm set-home-activity "app.titanius.launcher/.MainActivity"
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
		if [[ $PC_MODE -eq 1 || $HYBRID_PC_MODE -eq 1 ]]; then
			
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
						FORCE_QUICKSTEP_HOME=*)
							# Enable launcher3 quickstep as home
							pm set-home-activity "com.android.launcher3/.LauncherProvider"
							;;
						SET_DI_WHITELIST=*)
							# Set DI whitelist
							# dumpsys deviceidle whitelist +<PACKAGE_NAME>
                            diwlpackages="${SET_DI_WHITELIST#*=}"
							diwlpackage_array=($(echo $diwlpackages | sed 's/,/ /g' | xargs))
                            for diwlpackage in "${diwlpackage_array[@]}"; do
								if [ ! -f /data/misc/bbconfig/$diwlpackage ]; then
									echo "SET_DI_WHITELIST: $diwlpackage"
									dumpsys deviceidle whitelist +$diwlpackage
									sleep 1
									mkdir -p /data/misc/bbconfig
									mkdir -p /data/misc/bbconfig/diwhitelist
									touch /data/misc/bbconfig/diwhitelist/$diwlpackage
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
						FORCE_DESKTOP_ON_EXTERNAL=*)
							# Enable desktop mode on external display (required for MultiDisplay Input)
							if [ "$FORCE_DESKTOP_ON_EXTERNAL" == "0" ]; then
								settings put global force_desktop_mode_on_external_displays ""
								settings put global force_allow_on_external ""
							else
								settings put global force_desktop_mode_on_external_displays 1
								settings put global force_allow_on_external 1
							fi
							;;
						FORCE_PRIMARY_ROTATION=*)
							# Force primary rotation

							# disable accellerometer rotation first
							settings put system accelerometer_rotation 0

							# options: 0:0, 1:90, 2:180, 3:270
							settings put system user_rotation "$FORCE_PRIMARY_ROTATION"
							;;
                    esac
                fi
                ;;
        esac
    done
	
}


# Allow iio options to be passed through cmdline
function set_iio_options()
{
	# Set up usb/adb props when values are detected in /proc/cmdline
	
	for c in `cat /proc/cmdline`; do
		case $c in
			*=*)
				eval $c
				if [ -z "$1" ]; then
					case $c in
						SET_IIO_ORDER=*)
							set_property ro.iio.accel.order "$SET_IIO_ORDER"
							;;
						SET_IIO_ACCEL_QUIRKS=*)
							set_property ro.iio.accel.quirks "$SET_IIO_ACCEL_QUIRKS"
							;;
						SET_IIO_ACCEL_X_OPT_SCALE=*)
							set_property ro.iio.accel.x.opt_scale "$SET_IIO_ACCEL_X_OPT_SCALE"
							;;
						SET_IIO_ACCEL_Y_OPT_SCALE=*)
							set_property ro.iio.accel.y.opt_scale "$SET_IIO_ACCEL_Y_OPT_SCALE"
							;;
						SET_IIO_ANGLVEL_QUIRKS=*)
							set_property ro.iio.anglvel.quirks "$SET_IIO_ANGLVEL_QUIRKS"
							;;
						SET_IGNORE_ATKBD=*)
							# (0,1) 0=off, 1=on
							set_property ro.ignore_atkbd "$SET_IGNORE_ATKBD"
							;;
						SET_IIO_MAGN_QUIRKS=*)
							set_property ro.iio.magn.quirks "$SET_IIO_MAGN_QUIRKS"
							;;
					esac
				fi
				;;
		esac
	done
}

function do_init()
{
	init_misc
	set_lowmem
	set_usb_mode
	set_custom_timezone
	init_hal_audio
	set_custom_ota
	set_max_logd
	init_hal_bluetooth
	init_hal_camera
	init_hal_gps
	init_hal_gralloc
	init_hal_hwcomposer
	init_hal_media
	init_hal_vulkan
	init_hal_lights
	init_hal_power
	init_hal_thermal
	init_hal_sensors
	init_hal_surface
	set_iio_options
	init_tscal
	init_ril
	init_loop_links
	init_prepare_ota
	post_init
}

function do_netconsole()
{
	modprobe netconsole netconsole="@/,@$(getprop dhcp.eth0.gateway)/"
}

function do_bootcomplete()
{
	hciconfig | grep -q hci || pm disable com.android.bluetooth

	init_cpu_governor

	[ -z "$(getprop persist.sys.root_access)" ] && setprop persist.sys.root_access 3

	lsmod | grep -Ehq "brcmfmac|rtl8723be" && setprop wlan.no-unload-driver 1

	case "$PRODUCT" in
		Surface*Go)
			echo on > /sys/devices/pci0000:00/0000:00:15.1/i2c_designware.1/power/control
			;;
		VMware*)
			pm disable com.android.bluetooth
			;;
		X80*Power)
			set_property power.nonboot-cpu-off 1
			;;
		*)
			;;
	esac

	# initialize audio in bootcomplete
	init_hal_audio_bootcomplete

	# check wifi setup
	FILE_CHECK=/data/misc/wifi/wpa_supplicant.conf

	if [ ! -f "$FILE_CHECK" ]; then
	    cp -a /system/etc/wifi/wpa_supplicant.conf $FILE_CHECK
            chown 1010.1010 $FILE_CHECK
            chmod 660 $FILE_CHECK
	fi

	POST_INST=/data/vendor/post_inst_complete
	USER_APPS=/system/etc/user_app/*
	BUILD_DATETIME=$(getprop ro.build.date.utc)
	POST_INST_NUM=$(cat $POST_INST)

	if [ ! "$BUILD_DATETIME" == "$POST_INST_NUM" ]; then
		for apk in $USER_APPS
		do		
			pm install $apk
		done
		rm "$POST_INST"
		touch "$POST_INST"
		echo $BUILD_DATETIME > "$POST_INST"
	fi

	#Auto activate XtMapper
	#nohup env LD_LIBRARY_PATH=$(echo /data/app/*/xtr.keymapper*/lib/x86_64) \
	#CLASSPATH=$(echo /data/app/*/xtr.keymapper*/base.apk) /system/bin/app_process \
	#/system/bin xtr.keymapper.server.InputService > /dev/null 2>&1 &

	if [ ! "$(getprop ro.boot.slot_suffix)" ]; then
		pm disable com.blissos.updater
		pm disable org.lineageos.updater
	fi

	set_custom_settings
	set_custom_package_perms
	set_package_opts

	post_bootcomplete
}

PATH=/sbin:/system/bin:/system/xbin

DMIPATH=/sys/class/dmi/id
BOARD=$(cat $DMIPATH/board_name)
PRODUCT=$(cat $DMIPATH/product_name)
VENDOR=$(cat $DMIPATH/sys_vendor)
UEVENT=$(cat $DMIPATH/uevent)

# import cmdline variables
for c in `cat /proc/cmdline`; do
	case $c in
		BOOT_IMAGE=*|iso-scan/*|*.*=*)
			;;
		nomodeset)
			HWACCEL=0
			;;
		*=*)
			eval $c
			if [ -z "$1" ]; then
				case $c in
					DEBUG=*)
						[ -n "$DEBUG" ] && set_property debug.logcat 1
						[ "$DEBUG" = "0" ] || SETUPWIZARD=${SETUPWIZARD:-0}
						;;
					SET_LOGCAT_DEBUG=*)
						set_property debug.logcat "$SET_LOGCAT_DEBUG"
						;;
					DPI=*)
						set_property ro.sf.lcd_density "$DPI"
						;;
					SUSPEND_TYPE=*)
						# Override auto-detected power suspend type
						# options: (https://www.kernel.org/doc/Documentation/power/interface.txt)
						# 	'freeze' (Suspend-to-Idle)
						# 	'standby' (Power-On Suspend)
						# 	'mem' (Suspend-to-RAM)
						# 	'disk' (Suspend-to-Disk)
						set_property sleep.state "$SUSPEND_TYPE"
						;;
					PWR_OFF_DBLCLK=*)
						# set power off double click
						# options: true,false
						set_property poweroff.doubleclick "$PWR_OFF_DBLCLK"
						;;
					SET_SECONDARY_DISPLAY_ORIENTATION=*)
						# Set target orientation for external displays (0=0, 1=90, 2=180, 3-270)
						setprop ro.boot.android.force_rotation_on_external_displays "$SET_SECONDARY_DISPLAY_ORIENTATION"
						;;
					# Battery Stats
					SET_FAKE_BATTERY_LEVEL=*)
						# Let us fake the total battery percentage
						# Range: 0-100
						dumpsys battery set level "$SET_FAKE_BATTERY_LEVEL"
						;;
					SET_FAKE_CHARGING_STATUS=*)
						# Allow forcing battery charging status
						# Off: 0  On: 1
						dumpsys battery set ac "$SET_FAKE_CHARGING_STATUS"
						;;
					SET_USB_BUS_PORTS=*)
						# Set USB bus ports
						# Example: SET_USB_BUS_PORTS=001/001,001/002,001/003,001/004
						genports="${SET_USB_BUS_PORTS#*=}"
						genports_array=($(echo $genports | sed 's/,/ /g' | xargs))
						# loop through each option
						for port in "${genports_array[@]}"; do
							# chown system:system /dev/bus/usb/$port
							chmod -R 777 /dev/bus/usb/$port
						done
						;;
					SET_TTY_PORT_PERMS=*)
						# Sets permissions for tty ports 
						# Example: SET_TTY_PORT_PERMS=ttyS0,ttyS1,ttyS2
						gentty="${SET_TTY_PORT_PERMS#*=}"
						gentty_array=($(echo $gentty | sed 's/,/ /g' | xargs))
						# loop through each option
						for tport in "${gentty_array[@]}"; do
							# chown system:system /dev/$tport
							chmod 666 /dev/$tport
						done
						;;
					FORCE_DISABLE_NAVIGATION=*)
						# Force disable navigation bar
						# options: true, false
						set_property persist.bliss.disable_navigation_bar "$FORCE_DISABLE_NAVIGATION"
						;;
					FORCE_DISABLE_NAV_HANDLE=*)
						# Force disable navigation handle
						# options: true, false
						set_property persist.bliss.disable_navigation_handle "$FORCE_DISABLE_NAV_HANDLE"
						;;
					FORCE_DISABLE_NAV_TASKBAR=*)
						# Force disable navigation taskbar
						# options: true, false
						set_property persist.bliss.disable_taskbar "$FORCE_DISABLE_NAV_TASKBAR"
						;;
					FORCE_DISABLE_STATUSBAR=*)
						# Force disable statusbar
						# options: true, false
						set_property persist.bliss.disable_statusbar "$FORCE_DISABLE_STATUSBAR"
						;;
					FORCE_DISABLE_RECENTS=*)
						# Force disable recents
						# options: true, false
						set_property persist.bliss.disable_recents "$FORCE_DISABLE_RECENTS"
						;;
					FORCE_HIDE_NAVBAR_WINDOW=*)
						# Force hide navigation bar window
						# options: 0, 1
						set_property persist.wm.debug.hide_navbar_window "$FORCE_HIDE_NAVBAR_WINDOW"
						;;
					FORCE_HW_TIMEOUT_MULTIPLIER=*)
						# Force hw timeout multiplier, # X 5s
						# options: (integer)
						set_property ro.hw_timeout_multiplier "$FORCE_HW_TIMEOUT_MULTIPLIER"
						;;
					BOOT_FACTORY_TEST=*)
						# Boot into factory test mode
						# options: 0, 1
						set_property ro.factorytest "$BOOT_FACTORY_MODE"
						;;
					FORCE_NAVBAR_ON_SECONDARY_DISPLAYS=*)
						# Force navigation bar on secondary displays
						# options: 0, 1
						set_property ro.boot.force.navbar_on_secondary_displays "$FORCE_NAVBAR_ON_SECONDARY_DISPLAYS"
						;;
					FORCE_IME_ON_SECONDARY_DISPLAYS=*)
						# Force IME on secondary displays
						# options: 0, 1
						set_property ro.boot.bliss.force_ime_on_all_displays "$FORCE_IME_ON_SECONDARY_DISPLAYS"
						;;
					SET_SECOND_DISPLAY_PKG=*)
						# For debugging purposes, if the activity's package name contains the value of
						# the "debug.use-second-display" system property as a substring, then show
						# its content on a secondary display if there is one.
						set_property debug.second-display.pkg "$SET_SECOND_DISPLAY_PKG"
						;;
				esac
				[ "$SETUPWIZARD" = "0" ] && set_property ro.setupwizard.mode DISABLED
			fi
			;;
	esac
done

[ -n "$DEBUG" ] && set -x || exec &> /dev/null

# import the vendor specific script
hw_sh=/vendor/etc/init.sh
[ -e $hw_sh ] && source $hw_sh

case "$1" in
	eglsetup)
		init_egl
		;;
	netconsole)
		[ -n "$DEBUG" ] && do_netconsole
		;;
	bootcomplete)
		do_bootcomplete
		;;
	init|"")
		do_init
		;;
esac

return 0
