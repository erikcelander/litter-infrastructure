#--------------------------------------------------------------------
# Provisioning
#

resource "null_resource" "provisioning_load_balancer" {
  depends_on = [
    openstack_compute_instance_v2.load_balancer
  ]

  triggers = {
    instance_id = openstack_compute_instance_v2.load_balancer.id
  }
 
  connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = var.private_key
      host                = openstack_compute_instance_v2.load_balancer.access_ip_v4
      bastion_host        = var.jump_host_ip
      bastion_private_key = file(var.identity_file)
      agent               = true
  }

  provisioner "remote-exec" {
      inline = [
          # Add the hostname to IP mapping for all instances
          "echo '${openstack_compute_instance_v2.load_balancer.access_ip_v4} ${openstack_compute_instance_v2.load_balancer.name}' | sudo tee -a /etc/hosts",
          "${join("\n", [for instance in openstack_compute_instance_v2.control_planes : "echo '${instance.access_ip_v4} ${instance.name}' | sudo tee -a /etc/hosts"])}",
          "${join("\n", [for instance in openstack_compute_instance_v2.workers : "echo '${instance.access_ip_v4} ${instance.name}' | sudo tee -a /etc/hosts"])}",

          # Set the hostname for the current instance
          "sudo hostnamectl set-hostname ${openstack_compute_instance_v2.load_balancer.name}",
      ]
  }
}

resource "null_resource" "provisioning_control_plane" {
  depends_on = [ 
    openstack_compute_instance_v2.control_planes
   ]
    
  # Apply this resource to each control plane instance
  count = length(openstack_compute_instance_v2.control_planes)

  triggers = {
    instance_id = "${openstack_compute_instance_v2.control_planes[count.index].id}"
  }

  connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = var.private_key
      host                = "${openstack_compute_instance_v2.control_planes[count.index].access_ip_v4}"
      bastion_host        = var.jump_host_ip
      bastion_private_key = file(var.identity_file)
      agent               = true
  }

  provisioner "remote-exec" {
      inline = [
          # Add the hostname to IP mapping for all instances
          "echo '${openstack_compute_instance_v2.load_balancer.access_ip_v4} ${openstack_compute_instance_v2.load_balancer.name}' | sudo tee -a /etc/hosts",
          "${join("\n", [for instance in openstack_compute_instance_v2.control_planes : "echo '${instance.access_ip_v4} ${instance.name}' | sudo tee -a /etc/hosts"])}",
          "${join("\n", [for instance in openstack_compute_instance_v2.workers : "echo '${instance.access_ip_v4} ${instance.name}' | sudo tee -a /etc/hosts"])}",
          
          # Set the hostname for the current instance
          "sudo hostnamectl set-hostname ${openstack_compute_instance_v2.control_planes[count.index].name}"
      ]
  }
}

resource "null_resource" "provisioning_workers" {
  depends_on = [ 
    openstack_compute_instance_v2.workers
  ]

  # Apply this resource to each worker instance
  count = length(openstack_compute_instance_v2.workers)

  triggers = {
    instance_id = "${openstack_compute_instance_v2.workers[count.index].id}"
  }

  connection {
    type                = "ssh"
    user                = "ubuntu"
    private_key         = var.private_key
    host                = "${openstack_compute_instance_v2.workers[count.index].access_ip_v4}"
    bastion_host        = var.jump_host_ip
    bastion_private_key = file(var.identity_file)
    agent               = true
  }

  provisioner "remote-exec" {
    inline = [
      # Add the hostname to IP mapping for all instances
      "echo '${openstack_compute_instance_v2.load_balancer.access_ip_v4} ${openstack_compute_instance_v2.load_balancer.name}' | sudo tee -a /etc/hosts",
      "${join("\n", [for instance in openstack_compute_instance_v2.control_planes : "echo '${instance.access_ip_v4} ${instance.name}' | sudo tee -a /etc/hosts"])}",
      "${join("\n", [for instance in openstack_compute_instance_v2.workers : "echo '${instance.access_ip_v4} ${instance.name}' | sudo tee -a /etc/hosts"])}",
          
      # Set the hostname for the current instance
      "sudo hostnamectl set-hostname ${openstack_compute_instance_v2.workers[count.index].name}"
    ]
  }
}
