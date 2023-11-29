#--------------------------------------------------------------------
# Data sources
#

# Retrieve the ID of the specified image
data "openstack_images_image_v2" "image" {
  name        = var.image_name
  most_recent = true
}

# Retrieve the ID of the specified flavor
data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor_name
}

# Retrieve the ID of the specified external network
data "openstack_networking_network_v2" "extnet" {
  name = var.external_network_name
}

# Retrieve the ID of the default security group
data "openstack_networking_secgroup_v2" "secgroup_default" {
  name = "default"
}

# Generate cloud-init configuration for instances
data "template_file" "template_file_cloudinit_lb" {
  template = file("${path.module}/.data/cloud-init-load-balancer.tpl")
}

data "template_file" "template_file_cloudinit" {
  template = file("${path.module}/.data/cloud-init-k8s.tpl")
}

data "template_file" "template_file_cloudinit_controls_plane" {
  template = file("${path.module}/.data/cloud-init-k8s-part-control-plane.tpl")
  vars = {
    control_plane_endpoint = "${var.control_plane_node_machine_name}-1" #openstack_compute_instance_v2.control_planes.0.name #"control-plane-1"
  }
}

# Generate cloud-init configuration specifically for the control plane
data "template_cloudinit_config" "cloudinit_control_plane_config" {
  gzip          = false
  base64_encode = true
  
  part {
    content_type = "text/cloud-config"
    content = data.template_file.template_file_cloudinit.rendered
    merge_type = "list(append)+dict(recurse_array)+str()"
  }

  part {
    content_type = "text/cloud-config"
    content = data.template_file.template_file_cloudinit_controls_plane.rendered
    merge_type = "list(append)+dict(recurse_array)+str()"
  }
}
