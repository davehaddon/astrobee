#!/bin/bash

# AB ethernet device 
LLP_DEVICE=lo
if ip link show $LLP_DEVICE > /dev/null
then 
	echo "LLP Device is $LLP_DEVICE"
else
	ip -c link show
	echo "Enter LLP device to use:"
	read LLP_DEVICE 
	if ip link show $LLP_DEVICE > /dev/null
	then 
		echo "LLP Device is $LLP_DEVICE"
	else
		echo "Unable to find device, not starting"
		exit 1
	fi
fi

if [[ "$@" == *"emu"* ]]
then
	# Using the Default Emulator aaddress..
	export HLP_IP=10.0.2.15
	export MLP_IP=10.0.2.2
	export LLP_IP=10.0.2.2

	export ROS_MASTER_URI=http://10.0.2.2:11311
	export ROS_IP=10.0.2.2

	export LLP_ADDRESS=${LLP_IP}/24
	echo "Adding Android Emulator default IP to $LLP_DEVICE"

	sudo ip add add $LLP_ADDRESS dev $LLP_DEVICE

	echo "rewriting local hosts file"

	sudo sed -i "s/^.*hlp/$HLP_IP       hlp/" /etc/hosts
    sudo sed -i "s/^.*mlp/$MLP_IP       mlp/" /etc/hosts
	sudo sed -i "s/^.*llp/$LLP_IP       llp/" /etc/hosts

	sudo ip route add 10.0.2.0/24 via 10.0.2.1 dev lo
	# cat /etc/hosts
	
	setup_emu=1
	if ps ac | grep qemu
	then
		echo "Emulator already running... Not starting it again"
		setup_emu=0
	else
		sudo -E ~/astrobee_ws/src/submodules/android/scripts/launch_emulator.sh -n &
		sleep 5
	fi
	while ! adb shell echo "OK"
	do 
		echo "Waiting for Emulator to become available to adb..."
		sleep 5
	done
	
	if [ $setup_emu ]
	then
		echo "ADB Found.  Setting HLP networks"
		adb root
		echo "Root"
		sleep 1
		echo "Remount"
		adb remount
		sleep 1
		adb push $ANDROID_PATH/scripts/emu_setup_default.sh /cache/
		adb push $ANDROID_PATH/scripts/hosts.emulator /system/etc/hosts
		#adb shell su 0 sh /cache/emulator_setup_net.sh
		adb shell su 0 sh /cache/emu_setup_default.sh
		echo "Unroot"
		adb unroot
	fi

	echo "Pinging HLP at $HLP_IP"
	if ping -w 2 -c 1 $HLP_IP
	then 
		echo -e "\n ++++ HLP Found from here +++++\n   ---- HOST IP ADDRESSES --------\n"
		
		ip -c a | tee net_good.txt
		echo -e " ----- HOST IP ROUTES ----------- " | tee -a net_good.txt
		ip -c r | tee -a net_good.txt

		echo -e "\n ------ EMULATOR IP ADDRESSES  ---------- \n" | tee -a net_good.txt
		
		adb shell ip -c a  | tee -a net_good.txt
		echo -e " -----  EMULATOR IP ROUTES ----------- "  | tee -a net_good.txt
		adb shell ip -c r  | tee -a net_good.txt

		echo -e " ---------------- \n\n"  | tee -a net_good.txt

	else 
		echo -e "\n ------ HLP Not found - Why??? ------ \n"
	
		echo -e "\v---- HOST IP ADDRESSES --------\n" 
		ip -c a | tee net_bad.txt
		echo -e " ----- HOST ROUTES ----------- " | tee -a net_bad.txt
		ip -c r | tee -a net_bad.txt

		echo -e "\n ------ EMULATOR IP ADDRESSES ---------- \n" | tee -a net_bad.txt
		
		adb shell ip -c a  | tee -a net_bad.txt
		echo -e " ------- EMULATOR ROUTES --------- "  | tee -a net_bad.txt
		adb shell ip -c r  | tee -a net_bad.txt

		echo -e " ---------------- \n\n"  | tee -a net_bad.txt
		exit 1

	fi

	echo "Pinging LLP ($LLP_IP) from the HLP (via adb)"

	if adb shell ping -w 1 -c 1 $LLP_IP
	then 
		echo -e "\n +++++  LLP Found from HLP  ++++++ \n"
	else 
		echo -e "\n----LLP Not found from HLP----\n"
		exit
	fi
else
	# No "emu" so we have a 'real' HLP android device connected
	# Check for LLP address on this host

	sudo sed -i "s/^.*hlp/10.42.0.36        hlp/" /etc/hosts
    sudo sed -i "s/^.*mlp/10.42.0.35        mlp/" /etc/hosts
	sudo sed -i "s/^.*llp/10.42.0.34        llp/" /etc/hosts

	LLP_ADDRESS=10.42.0.34/24
	
	if ip a | grep $LLP_DEVICE | grep 10.42.0.34
	then
		echo "LLP address already exists, the Astrobee network may already exist"
	else
		sudo ip addr add $LLP_ADDRESS dev $LLP_DEVICE
	fi
	# Can we ping the HLP unit?
	if ping -w 1 -c 1 10.42.0.36 > /dev/null
	then
		echo "HLP network is probably already done"		
	else
		~/astrobee_ws/src/submodules/android/scripts/hlp_setup_net.sh
	fi
fi

rviz=true
if [[ "$@" == *"norviz"* ]]
then
	rviz=false
fi

speed=""
if [[ "$@" == *"speed"* ]]
then
	speed=" speed:=$(echo $@ | sed 's/^.*speed=\([0-9.]*\)/\1/')"
fi

if [[ "$@" == *"test"* ]]
then
	echo "No launch"
elif [[ "$@" == *"model"* ]]
then
	echo roslaunch astrobee model_only.launch rviz:=$rviz dds:=false
	roslaunch astrobee model_only.launch rviz:=$rviz dds:=false
	exit
elif [[ "$@" == *"iss"* ]]
then
	echo "Launching Sim.launch... ready for takeoff!!!! @ ${speed}x"
	echo "roslaunch astrobee sim.launch rviz:=$rviz dds:=false robot:=sim_pub $speed"
	roslaunch astrobee sim.launch rviz:=$rviz dds:=false robot:=sim_pub $speed
else
	echo "Launching Sim.launch for the Granite Lab... @ ${speed}x"
	roslaunch astrobee sim.launch rviz:=$rviz dds:=false robot:=sim_pub world:=granite $speed
fi

sudo ip add del $LLP_ADDRESS dev $LLP_DEVICE

