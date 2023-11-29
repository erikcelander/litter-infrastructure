#!/bin/bash

# Script name: update-nginx-upstream.sh
# Author: mats.loock@lnu.se
#
# Description:
# This script configures a part of the NGINX configuration on the load balancer. It can take an SSH key (optional), the load balancer's hostname, and a list of worker node hostnames as arguments, or it can read the hostnames from an SSH config file.
#
# Usage:
# ./nginx-config.sh -lb load_balancer -w worker_1,worker_2 -i /path/to/your/key
# ./nginx-config.sh -f /path/to/your/ssh_config
#
# Options:
# -i: The path to the SSH key file (optional).
# -lb: The load balancer's hostname (optional if -f is used).
# -w: A comma-separated list of worker node hostnames (optional if -f is used).
# -f: The path to the SSH config file. The file should contain a line with "Host <hostname>", followed by "HostName <IP>" on the next line.

# TODO: Retrive the control plane IPs from the K8s cluster instead of from the .ssh/config file. Remove all options but -i, -lb and -f.
#       $ kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath="{.items[*].status.addresses[?(@.type=='InternalIP')].address}"

parse_options() {
    # Parse command-line options
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -i)
                if [[ -z "$2" || "$2" == -* ]]; then
                    echo "Error: -i requires an argument" 1>&2
                    usage
                    exit 1
                fi
                ssh_key="$2"
                shift 2
                ;;
            -lb)
                if [[ -z "$2" || "$2" == -* ]]; then
                    echo "Error: -lb requires an argument" 1>&2
                    usage
                    exit 1
                fi
                load_balancer="$2"
                shift 2
                ;;
            -w)
                if [[ -z "$2" || "$2" == -* ]]; then
                    echo "Error: -w requires an argument" 1>&2
                    usage
                    exit 1
                fi
                workers="$2"
                shift 2
                ;;
            -f)
                if [[ -n "$2" && "$2" != -* ]]; then
                    ssh_config_file="$2"
                    shift 2
                else
                    ssh_config_file="/home/ubuntu/.ssh/config"
                    shift
                fi
                ;;
            *)
                echo "Invalid option: $1" 1>&2
                usage
                exit 1
                ;;
        esac
    done

    # Check if SSH key file exists
    if [[ -n "$ssh_key" && ! -f "$ssh_key" ]]; then
        echo "SSH key file not found at \"$ssh_key\""
        exit 1
    fi

    # If a SSH config file is specified, read load balancer and worker nodes from the file
    if [[ -n "$ssh_config_file" ]]; then
        if [[ ! -f "$ssh_config_file" ]]; then
            echo "SSH config file not found at \"$ssh_config_file\""
            exit 1
        fi

        # Read load balancer and worker nodes from the SSH config file
        load_balancer=$(awk '/Host .*load-balancer/ {getline; print $2}' "$ssh_config_file")
        workers=$(awk '/Host .*worker-/ {getline; print $2}' "$ssh_config_file" | paste -sd "," -)
    fi

    # Check if LOAD_BALANCER or CONTROL_PLANES is empty
    if [[ -z "$load_balancer" || -z "$workers" ]]; then
        echo "Error: Load balancer and worker nodes are required"
        usage
        exit 1
    fi
}

configure_nginx() {
    local load_balancer=$1
    local workers=$2
    local ssh_key=$3

    # Convert the comma-separated list of worker nodes to an array
    IFS=',' read -r -a workers_array <<< "$workers"

    # Start building the upstream server configuration string
    local upstream_servers=""
    for control_plane in "${workers_array[@]}"; do
        upstream_servers+="    server ${control_plane};\n"
    done

    # Remove the trailing newline from the upstream server configuration string
    upstream_servers=${upstream_servers%\\n}

    # Configure NGINX on the load balancer to use the workers as upstream servers
    echo "${load_balancer} configuring NGINX to use workers as upstream servers"
    if ssh -o StrictHostKeyChecking=no ${ssh_key:+-i "$ssh_key"} ubuntu@"$load_balancer" "
        sudo sed -i '/upstream worker-nodes/,/}/{/^[[:space:]]*server/d}' /etc/nginx/sites-available/nginx.conf
        echo -e '${upstream_servers}' | sudo sed -i '/upstream worker-nodes/ r /dev/stdin' /etc/nginx/sites-available/nginx.conf
        sudo systemctl restart nginx
    "; then
        echo "${load_balancer} successfully configured NGINX to use worker nodes as upstream servers"
    else
        echo "${load_balancer} failed to configure NGINX to use worker nodes as upstream servers"
    fi
}

usage() {
    echo "Usage: nginx-config.sh [-i <ssh_key>] [-lb <load_balancer>] [-w <workers>] [-f <ssh_config_file>]"
    echo "Options:"
    echo "  -i <ssh_key>                 The path to the SSH key file (optional)."
    echo "  -lb <load_balancer>          The load balancer's hostname (optional if -f is used)."
    echo "  -w <workers>                 A comma-separated list of worker node hostnames (optional if -f is used)."
    echo "  -f <ssh_config_file>         The path to the SSH config file (optional)."
}

# Initialize variables and parse command-line options
ssh_key=""
load_balancer=""
workers=""
ssh_config_file=""

parse_options "$@"

echo "-------------------------------------------"
if [[ -n "${ssh_key}" ]]; then
    echo "SSH key         : ${ssh_key}"
fi
if [[ -n "$ssh_config_file}" ]]; then
    echo "SSH config file : ${ssh_config_file}"
fi
echo "Load balancer   : $load_balancer"
echo "Workers         : $workers"
echo "-------------------------------------------"

# Configure NGINX on the load balancer to use the workers as upstream servers
configure_nginx "${load_balancer}" "${workers}" "${ssh_key}"

echo -e "\n-------------------------------------------\nAll attempts to configure NGINX have finished. Please ensure that the hostname 'k8s-load-balancer' is resolvable to the correct IP address, and user, on your network. Then, run \n\n    ssh k8s-load-balancer \"cat /etc/nginx/sites-available/nginx.conf\"\n\nto see the NGINX configuration file's content.\n-------------------------------------------\n"
