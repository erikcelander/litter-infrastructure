#--------------------------------------------------------------------
# Provisioning
#
resource "null_resource" "provisioning_jump_host" {
    triggers = {
        jump_host_ips     = module.jump_host.jump_host_ips
        control_plane_ips = join(",", module.k8s.control_plane_ips)
        worker_ips        = join(",", module.k8s.worker_ips)
    }    
    
    connection {
        user        = "ubuntu"
        private_key = file(var.identity_file)
        host        = element(split(", ", module.jump_host.jump_host_ips), 0)
    }

    # Creates a file at "/home/ubuntu/.ssh/config" with SSH configuration.
    provisioner "file" {
        destination = "/home/ubuntu/.ssh/config"
        content = <<-EOF
        Host k8s-load-balancer
            HostName ${element(split(", ", module.k8s.load_balancer_ips), 1)}
            User ubuntu
        ${join("\n", [for idx, ip in module.k8s.control_plane_ips : "Host k8s-control-plane-${idx+1}\n    HostName ${ip}\n    User ubuntu"])}
        ${join("\n", [for idx, ip in module.k8s.worker_ips : "Host k8s-worker-${idx+1}\n    HostName ${ip}\n    User ubuntu"])}
        EOF
    }

    # Converts line endings from CRLF to LF in the hosts file.
    provisioner "remote-exec" {
        inline = [
            "chmod 600 ~/.ssh/config",
            "sed -i 's/\r$//' /home/ubuntu/.ssh/config"
        ]
    }  
}
