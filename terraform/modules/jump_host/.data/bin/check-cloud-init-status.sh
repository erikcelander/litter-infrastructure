#!/bin/bash

# filename: check-cloud-init-status.sh
# author: mats.loock@lnu.se

# Description:
# This script checks the cloud-init status on a list of hosts. It can read the hosts from a file or from the command-line arguments.
# If a hosts file is specified with the -f option, the script ignores any additional addresses.
#
# Options:
# -i: The path to the SSH key file (optional).
# -f: The path to the hosts file (optional). Default is /home/ubuntu/.ssh/config.
#
# Usage:
# ./check-cloud-init-status.sh 192.168.5.5 192.168.5.10 192.168.5.15 192.168.5.13
# ./check-cloud-init-status.sh -i /path/to/your/key 192.168.5.5 192.168.5.10 192.168.5.15 192.168.5.13
# ./check-cloud-init-status.sh -f
# ./check-cloud-init-status.sh -f /path/to/your/hosts
# ./check-cloud-init-status.sh -i /path/to/your/key -f /path/to/your/hosts

# Function to print usage information
usage() {
    echo "Usage:"
    echo "./check-cloud-init-status.sh 192.168.5.5 192.168.5.10 192.168.5.15 192.168.5.13"
    echo "./check-cloud-init-status.sh -i /path/to/your/key 192.168.5.5 192.168.5.10 192.168.5.15 192.168.5.13"
    echo "./check-cloud-init-status.sh -f"
    echo "./check-cloud-init-status.sh -f /path/to/your/hosts"
    echo "./check-cloud-init-status.sh -i /path/to/your/key -f /path/to/your/hosts"
    exit 1
}

# Function to check if cloud-init is done
check_cloud_init() {
    ip=$1
    hostname=$(awk -v ip=$ip '/Host /{host = substr($0, 6); getline; if ($2 == ip) print host}' "$SSH_CONFIG_FILE")
    host_info="${hostname} (${ip})"
    while true; do
        ssh_output=$(ssh -o StrictHostKeyChecking=no ${SSH_KEY:+-i "$SSH_KEY"} ubuntu@$ip "grep 'The system is finally up, after' /var/log/cloud-init-output.log" 2>&1)
        exit_status=$?
        if [[ $exit_status -ne 0 ]]; then
            if [[ -z "$ssh_output" ]]; then
                echo "$host_info: SSH error: Unable to retrieve output. Waiting to try again..."
            else
                echo "$host_info: SSH error: $ssh_output. Waiting to try again..."
            fi
            sleep 10
        elif [[ $ssh_output == *"The system is finally up, after"* ]]; then
            echo "$host_info: cloud-init finished ... done!"
            return 0
        else
            echo "$host_info: Waiting for cloud-init to finish..."
            sleep 10
        fi
    done
}
# Initialize variables
SSH_KEY=""
SSH_CONFIG_FILE=""

# Check if -f is used with other arguments
if [[ "$*" == *"-f"* && "$*" != *"-i"* && $# -gt 2 ]]; then
    echo "Error: Cannot combine -f option with other arguments" 1>&2
    usage
fi

if [[ "$*" == *"-f"* && "$*" == *"-i"* && $# -gt 4 ]]; then
    echo "Error: Cannot combine -f and -i options with other arguments" 1>&2
    usage
fi


# Parse command-line options
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h)
            usage
            ;;
        -i)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: -i requires an argument" 1>&2
                usage
            fi
            SSH_KEY="$2"
            shift 2
            ;;
        -f)
            if [[ -n "$2" && "$2" != -* ]]; then
                SSH_CONFIG_FILE="$2"
                shift 2
            else
                SSH_CONFIG_FILE="/home/ubuntu/.ssh/config"
                shift
            fi
            ;;
        *)
            if [[ "$1" == -* ]]; then
                echo "Invalid option: $1" 1>&2
                usage
            fi
            break
            ;;
    esac
done

# Check if SSH key file exists
if [[ -n "$SSH_KEY" && ! -f "$SSH_KEY" ]]; then
    echo "SSH key file not found at $SSH_KEY"
    exit 1
fi

# If a SSH config file is specified, read hosts from the file
if [[ -n "$SSH_CONFIG_FILE" ]]; then
    if [[ ! -f "$SSH_CONFIG_FILE" ]]; then
        echo "SSH config file not found at $SSH_CONFIG_FILE"
        exit 1
    fi

    # Read control plane IP and worker IPs from the SSH config file
    ALL_IPS=$(awk '/Host .*load-balancer|Host .*control-plane|Host .*worker-/ {getline; print $2}' "$SSH_CONFIG_FILE" | paste -sd " " -)

    # Verify ALL_IPS contains any addresses
    if [[ -z "$ALL_IPS" ]]; then
        echo "No IP address(es) found in the SSH config file"
        exit 1
    fi
else
    # If no SSH config file is specified, read hosts from the command-line arguments
    ALL_IPS="$@"
fi

# Check if any hosts are specified
if [[ -z "$ALL_IPS" ]]; then
    echo "No IP address(es) specified. Running \"cloud-init status --wait\" on the local machine..."
    cloud-init status --wait
    echo "cloud-init finished on the local machine"
    exit 0
fi

# Iterate over each hostname
for IP in $ALL_IPS; do
    check_cloud_init $IP &
done

# Wait for all background jobs to finish
wait

echo "Finished checking cloud-init status on all hosts. Verify the output above. If any host failed, run the script again."
