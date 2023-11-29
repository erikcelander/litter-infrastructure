#cloud-config
package_update: true
package_upgrade: true
package_reboot_if_required: true

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - software-properties-common

locale: "en_US.UTF-8"
timezone: "Europe/Stockholm"

write_files:
  - path: /etc/modules-load.d/k8s.conf
    content: |
      overlay
      br_netfilter

  - path: /etc/sysctl.d/kubernetes.conf
    content: |
      net.bridge.bridge-nf-call-iptables  = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward                 = 1

runcmd:
  # Enable kernel modules and disable SWAP
  - |
    modprobe overlay
    modprobe br_netfilter
    sysctl --system
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
  
  # Add Docker repo
  - |
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Install containerd
  - |
    apt update -y
    apt install -y containerd.io

  # Configure containerd and start service
  - |
    mkdir -p /etc/containerd
    containerd config default|sudo tee /etc/containerd/config.toml

  # Enable the systemd cgroup driver for the containerd container runtime
  - sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

  # Restart containerd
  - |
    systemctl restart containerd
    systemctl enable containerd
    systemctl status containerd

  # Install Kubernetes package
  - |
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list

  - |
    apt update -y
    apt install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl
  
  # Enable kubelet service
  - systemctl enable kubelet

  # Clean up unneeded packages and files to free up disk space
  - |
    apt autoremove -y
    apt clean -y

final_message: "The system is finally up, after $UPTIME seconds"
