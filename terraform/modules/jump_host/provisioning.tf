#--------------------------------------------------------------------
# Provisioning
#
resource "null_resource" "provisioning" {
    triggers = {
        instance_id = openstack_compute_instance_v2.jump_host.id
    }    
    
    connection {
        user        = "ubuntu"
        private_key = file(var.identity_file)
        host        = openstack_networking_floatingip_v2.floatingip.address
    }

    provisioner "local-exec" {
        command = "ssh-keygen -R ${openstack_networking_floatingip_v2.floatingip.address}"
    }

    provisioner "file" {
        source      = "${path.module}/.data/bin"
        destination = "/home/ubuntu/"
    }

    provisioner "remote-exec" {
        inline = [
            # Remove carriage return characters (HACK: Windows)
            "sed -i 's/\r$//' /home/ubuntu/bin/*.sh",

            # Make all files in the bin directory executable
            "chmod +x /home/ubuntu/bin/*",

            # Add the csw function to the .bashrc file
            "echo 'csw() { /home/ubuntu/bin/check-cloud-init-status.sh \"'\\$'@\"; }' >> /home/ubuntu/.bashrc",

            # Write the private key to the .ssh/id_rsa file and set its permissions
            "echo '${var.private_key_pem}' > /home/ubuntu/.ssh/id_rsa",
            "chmod 600 /home/ubuntu/.ssh/id_rsa",

            # Add commands to start the ssh-agent and add the private key to it to the .bashrc file
            "echo 'eval \"$(ssh-agent)\"' >> /home/ubuntu/.bashrc",
            "echo 'ssh-add' >> /home/ubuntu/.bashrc",
        ]
    }
}
