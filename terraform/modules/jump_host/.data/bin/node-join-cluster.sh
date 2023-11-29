#!/bin/bash

# Script name: node-join-cluster.sh
# Author: mats.loock@lnu.se
#
# Description:
# This script joins multiple nodes to a Kubernetes cluster. It can take an SSH key (optional), a primary control plane IP, and a list of worker IPs as arguments. Alternatively, it can read the control plane IP and worker IPs from an SSH config file.
#
# Usage:
# ./node-join-cluster.sh -p 192.168.5.5 -w 192.168.5.10,192.168.5.15,192.168.5.13
# ./node-join-cluster.sh -i /path/to/your/key -p 192.168.5.5 -w 192.168.5.10,192.168.5.15,192.168.5.13
# ./node-join-cluster.sh -f /path/to/your/ssh_config
# ./node-join-cluster.sh -i /path/to/your/key -f /path/to/your/ssh_config
#
# Options:
# -i: The path to the SSH key file (optional).
# -p: The primary control plane IP (optional if -f is used).
# -c: A comma-separated list of additional control plane IPs (optional if -f is used).
# -w: A comma-separated list of worker IPs (optional if -f is used).
# -f: The path to the SSH config file. The file should contain a line with "Host control-plane", followed by "HostName <PRIMARY_CONTROL_PLANE_IP>" on the next line, and a line with "Host worker-<n>", followed by "HostName <worker_ip>" on the following lines.
#
# Note: The -f option cannot be used with -p, -c and -w. Also, -p and -w and/or -c must be used together.

# TODO: Add labels to worker nodes,  e.g. kubectl label node k8s-worker-1 node-role.kubernetes.io/worker=worker.
#       All worker nodes: kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep 'worker' | xargs -I {} kubectl label node {} node-role.kubernetes.io/worker=worker


# This function parses the command-line options passed to the script and returns an associative array with the corresponding values.
# It also performs some basic validation of the options and prints error messages if necessary.
# Parameters: The command-line arguments passed to the script.
parse_options() {
    # Check if the command line contains -f and -w and/or -c
    if [[ "$*" =~ "-f" && ("$*" =~ "-w" || "$*" =~ "-c") ]]; then
        echo "Error: -f cannot be used with -c or -w"
        usage
        exit 1
    fi

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
            -p)
                if [[ -z "$2" || "$2" == -* ]]; then
                    echo "Error: -p requires an argument" 1>&2
                    usage
                    exit 1
                fi
                primary_control_plane_ip="$2"
                shift 2
                ;;
            -c)
                if [[ -z "$2" || "$2" == -* ]]; then
                    echo "Error: -c requires an argument" 1>&2
                    usage
                    exit 1
                fi
                control_plane_ips="$2"
                shift 2
                ;;
            -w)
                if [[ -z "$2" || "$2" == -* ]]; then
                    echo "Error: -w requires an argument" 1>&2
                    usage
                    exit 1
                fi
                worker_ips="$2"
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

    # Check if -p and -w are used together
    if [[ (-n "$primary_control_plane_ip" && -z "$worker_ips") || (-z "$primary_control_plane_ip" && -n "$worker_ips") ]]; then
        echo "Error: -p and -w must be used together"
        usage
        exit 1
    fi

    # If a SSH config file is specified, read control plane IP and worker IPs from the file
    if [[ -n "$ssh_config_file" ]]; then
        if [[ ! -f "$ssh_config_file" ]]; then
            echo "SSH config file not found at \"$ssh_config_file\""
            exit 1
        fi

        # Read primary control plane IP, other control plane IPs, and worker IPs from the SSH config file
        primary_control_plane_ip=$(awk '/Host k8s-control-plane-1/ {getline; print $2}' "$ssh_config_file")
        control_plane_ips=$(awk '/Host k8s-control-plane-/ && !/Host k8s-control-plane-1/ {getline; print $2}' "$ssh_config_file" | paste -sd "," -)
        worker_ips=$(awk '/Host k8s-worker-/ {getline; print $2}' "$ssh_config_file" | paste -sd "," -)
    fi

    # Check if PRIMARY_CONTROL_PLANE_IP or WORKER_IPS is empty
    if [[ -z "$primary_control_plane_ip" || -z "$worker_ips" ]]; then
        echo "Error: Primary control plane IP adress and worker IP adresses are required"
        usage
        exit 1
    fi
}

# This function joins a node to the Kubernetes cluster.
# Parameters:
# - $1: The IP address of the node.
# - $2: The join command to use.
# - $3: The IP address of the primary control plane (set if the joining node is a control plane node).
# - $4: The path to the SSH key file.
join_node() {
    local ip=$1
    local join_cmd=$2
    local primary_control_plane_ip=$3
    local ssh_key=$4

    echo "${ip} attempting to join cluster"
    if ssh -o StrictHostKeyChecking=no ${ssh_key:+-i "$ssh_key"} ubuntu@"$ip" "sudo $join_cmd"; then
        echo "${ip} successfully joined the cluster"

        # If the primary_control_plane_ip variable is set, the node is a control plane node
        if [[ -n "$primary_control_plane_ip" ]]; then
            echo "Copying kubeconfig file to ${ip}"
            scp -o StrictHostKeyChecking=no ${ssh_key:+-i "$ssh_key"} ubuntu@"$primary_control_plane_ip":/home/ubuntu/.kube/config ubuntu@"$ip":/home/ubuntu/.kube/
        fi
    else
        echo "${ip} failed to join the cluster"
    fi
}

# This function joins the control plane nodes to the Kubernetes cluster.
# It iterates over each IP address in the control_plane_ips_array and calls the join_node function to join the node to the cluster.
# Parameters: 
# - $1: A comma-separated list of control plane IPs.
# - $2: The join command to use.
# - $3: The IP address of the primary control plane.
# - $4: The path to the SSH key file.
join_control_plane_nodes() {
    local control_plane_ips=$1
    local join_cmd=$2
    local primary_control_plane_ip=$3
    local ssh_key=$4

    # Convert the comma-separated list of control plane IPs to an array
    IFS=',' read -r -a control_plane_ips_array <<< "$control_plane_ips"

    # Start the spinner in the background
    echo -n "Generating certificate for additional control plane(s)"
    while :; do echo -n .; sleep 1; done &

    # Save the PID of the spinner
    local spinner_pid=$!

    # Handle SIGINT
    trap 'kill $spinner_pid; echo; echo "Interrupted"; return 1' INT

    # Generate a new certificate key on the control plane node
    local certificate_key
    if certificate_key=$(ssh -o StrictHostKeyChecking=no ${ssh_key:+-i "$ssh_key"} ubuntu@"$primary_control_plane_ip" "sudo kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -n 1"); then
        echo -e "\nCertificate generated successfully"
    else
        # Stop the spinner and print an error message if the command fails
        kill $spinner_pid
        echo
        echo -e "\nFailed to generate certificate"
        return 1
    fi

    # Stop the spinner
    kill $spinner_pid
    echo

    # Iterate over each IP address in the control plane IPs array
    for IP in "${control_plane_ips_array[@]}"
    do
        echo "--certificate-key $certificate_key"

        # Join the control plane node to the cluster
        join_node "$IP" "$join_cmd --control-plane --certificate-key $certificate_key" "$primary_control_plane_ip" "$ssh_key" &
    done
}

# This function joins the worker nodes to the Kubernetes cluster.
# It iterates over each IP address in the worker_ips_array and calls the join_node function to join the node to the cluster.
# Parameters: 
# - $1: A comma-separated list of worker IPs.
# - $2: The join command to use.
# - $3: The path to the SSH key file.
join_worker_nodes() {
    local worker_ips=$1
    local join_cmd=$2
    local ssh_key=$3

    # Convert the comma-separated list of worker IPs to an array
    IFS=',' read -r -a worker_ips_array <<< "$worker_ips"

    # Iterate over each IP address in the worker IPs array
    for IP in "${worker_ips_array[@]}"
    do
        # Join the worker node to the cluster
        join_node "$IP" "$join_cmd" "" "$ssh_key" &
    done
}

# This function displays usage information for the script.
# Parameters: None
usage() {
    echo "Usage: node-join-cluster.sh [-i <ssh_key>] [-p <primary_control_plane_ip>] [-c <control_plane_ips>] [-w <worker_ips>] [-f <ssh_config_file>]"
    echo "Options:"
    echo "  -i <ssh_key>                 The path to the SSH key file (optional)."
    echo "  -p <primary_control_plane_ip> The primary control plane (control-plane-1) IP (optional if -f is used)."
    echo "  -c <control_plane_ips>       A comma-separated list of additional control plane IPs (optional if -f is used)."
    echo "  -w <worker_ips>              A comma-separated list of worker IPs (optional if -f is used)."
    echo "  -f <ssh_config_file>         The path to the SSH config file. The file should contain a line with \"Host control-plane\", followed by \"HostName <PRIMARY_CONTROL_PLANE_IP>\" on the next line, and a line with \"Host worker-<n>\", followed by \"HostName <worker_ip>\" on the following lines."
}

# Initialize variables and parse command-line options
control_plane_ips=""
primary_control_plane_ip=""
ssh_config_file=""
ssh_key=""
worker_ips=""

parse_options "$@"

echo "-------------------------------------------"
if [[ -n "${ssh_key}" ]]; then
    echo "SSH key         : ${ssh_key}"
fi
if [[ -n "$ssh_config_file}" ]]; then
    echo "SSH config file : ${ssh_config_file}"
fi
echo "Primary control plane IP: $primary_control_plane_ip"
echo "Other control plane IPs : $control_plane_ips"
echo "Worker IPs              : $worker_ips"
echo "-------------------------------------------"

# Create a join command using kubeadm
join_cmd=$(ssh -o StrictHostKeyChecking=no ${ssh_key:+-i "${ssh_key}"} ubuntu@"${primary_control_plane_ip}" "sudo kubeadm token create --print-join-command")
echo "Join command: $join_cmd"

# Disable job control
set +m

# Convert the comma-separated list of control plane IPs and worker IPs to arrays
IFS=',' read -r -a control_plane_ips_array <<< "${control_plane_ips}"
IFS=',' read -r -a worker_ips_array <<< "${worker_ips}"

# Join control plane nodes to the cluster
if [[ -n "$control_plane_ips" ]]; then
    join_control_plane_nodes "${control_plane_ips}" "$join_cmd" "${primary_control_plane_ip}" "${ssh_key}"
fi

# Join worker nodes to the cluster
join_worker_nodes "${worker_ips}" "$join_cmd" "${ssh_key}"

# Wait for all background jobs to finish
wait

echo -e "\n-------------------------------------------\nAll attempts to join the cluster have finished. Please ensure that the hostname 'k8s-control-plane-1' is resolvable to the correct IP address, and user, on your network. Then, run \n\n    ssh k8s-control-plane-1 \"kubectl get nodes\"\n\nto see these nodes join the cluster.\n-------------------------------------------\n"


# # --------------------------------------------------------------------
# # NGINX configuration
# #

# # Remove old server entries from the upstream block
# "sudo sed -i '/upstream control-planes/,/}/{/server/d}' /etc/nginx/sites-available/nginx.conf",

# # Add new server entries to the upstream block
# "${join("\n", [for instance in openstack_compute_instance_v2.control_planes : "echo '        server ${instance.access_ip_v4};' | sudo tee -a /etc/nginx/sites-available/nginx.conf"])}",

# # Restart the NGINX service to apply the changes
# "sudo systemctl restart nginx"          
