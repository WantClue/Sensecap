#!/bin/bash


#paths


function install() {
    echo -e "Module: Install ThingsIX"
	echo -e "================================================================"
	if [[ "$USER" != "root" ]]; then
		echo -e "You are currently logged in as $USER"
		echo -e "Please switch to the root account use command 'sudo su -'."
		echo -e "================================================================"
		echo -e ""
		exit
	fi

    # find the forwarder container
    local container_name_prefix="pktfwd_"
    local container_name=""

    # Get a list of running containers
    local running_containers=$(balena ps --format "{{.ID}} {{.Names}}")

    # Loop through each running container
    while read -r container_info; do
        local container_id=$(echo "$container_info" | awk '{print $1}')
        local container_name=$(echo "$container_info" | awk '{print $2}')

        # Check if the container name starts with the specified prefix
        if [[ "$container_name" == "${container_name_prefix}"* ]]; then
            # Save the complete container name in a variable
            found_container="$container_name"
            break  # Exit the loop if a matching container is found
        fi
    done <<< "$running_containers"

    # Check if a matching container was found
    if [ -n "$found_container" ]; then
        echo "Found container with name: $found_container"
    else
        echo "No container with name starting with $container_name_prefix found."
        echo "Check your hotspot or reach out to WantClue for further information"
        exit
    fi

    # edit pktfwd
    balena exec $found_container sed -i 's/"serv_port_up": [0-9]*,/"serv_port_up": 1681,/' global_conf.json.sx1250.EU868
    balena exec $found_container sed -i 's/"serv_port_up": [0-9]*,/"serv_port_up": 1681,/' global_conf.json.sx1250.EU868
    
    # store id
    id=$(balena exec $found_container sed -n 's/.*"gateway_ID": "\(.*\)",/\1/p' global_conf.json.sx1250.EU868)

    # create the gwmp-mux
    echo "Now we need to create the multiplexer to use Helium and ThingsIX"
    balena run -d --restart unless-stopped --network host --name gwmp-mux ghcr.io/thingsixfoundation/gwmp-mux:latest --host 1681 --client 127.0.0.1:1680 --client 127.0.0.1:1685

    # create thingsix-forwarder container
    balena run -d --name thingsix-forwarder -p 1685:1680/udp --restart unless-stopped -v /mnt/data/thix:/etc/thingsix-forwarder ghcr.io/thingsixfoundation/packet-handling/forwarder:latest --net=main

    echo ="Now we have created everything. We need to restart the container quickly"
    sleep 5
    balena restart gwmp-mux
    balena restart $found_container
    
    # onboard the gateway to ThingsIX
    echo ="Your local id is $id"
    echo ="Please insert your Polygon Address to onboard this gateway to your wallet"
    read wallet
    balena exec thingsix-forwarder ./forwarder onboard-and-push $id $wallet

    echo ="Congratulations your device is now onboarded to ThingsIX"
}

echo -e ""
echo -e "================================================================"
echo -e "OS: BalenaOS "
echo -e "Created by: WantClue"
echo -e "================================================================"
echo -e "1  - Installation of ThingsIX forwarder and onboard"
echo -e "3  - Abort"
echo -e "================================================================"

read -rp "Pick an option and hit ENTER: "
case "$REPLY" in
 1)  
		clear
		sleep 1
		install
 ;;
 2) 
		clear
		sleep 1
		exit
 ;;
esac