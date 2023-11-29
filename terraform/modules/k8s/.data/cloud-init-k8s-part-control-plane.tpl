#cloud-config
runcmd:
  # Setup the Kubernetes Control Plane
  # CIDR: 172.16.0.0/12 => 172.16.0.0 to 172.31.255.255
  - |
    kubeadm config images pull
    kubeadm init --pod-network-cidr=172.16.0.0/12 --upload-certs --control-plane-endpoint=${control_plane_endpoint}

  - |
    mkdir -p /home/ubuntu/.kube
    chown ubuntu:ubuntu /home/ubuntu/.kube
    cp -f /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
    chown ubuntu:ubuntu /home/ubuntu/.kube/config

  # Setup the Pod Network
  - sudo -i -u ubuntu bash -c 'kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml'
  
  # Install Helm package
  - |
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    apt-get install apt-transport-https --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    apt-get update
    apt-get install helm
