#--------------------------------------------------------------------
# Resource for creating the control plane instance in OpenStack
#

resource "openstack_compute_instance_v2" "control_planes" {
  depends_on        = [openstack_networking_router_interface_v2.router_interface]
  count             = var.control_plane_node_count
  name              = "${var.control_plane_node_machine_name}-${count.index + 1}"
  image_id          = data.openstack_images_image_v2.image.id
  flavor_id         = data.openstack_compute_flavor_v2.flavor.id
  key_pair          = var.key_pair
  availability_zone = "Education"
  user_data         = (count.index == 0
                        ? data.template_cloudinit_config.cloudinit_control_plane_config.rendered
                        : data.template_file.template_file_cloudinit.rendered
                      )
  network {
    port = "${element(openstack_networking_port_v2.ports_control_plane_nodes.*.id, count.index)}"
  }
}

#--------------------------------------------------------------------
# Resource for creating worker instances in OpenStack
#
resource "openstack_compute_instance_v2" "workers" {
  depends_on        = [openstack_networking_router_interface_v2.router_interface]
  count             = var.worker_node_count
  name              = "${var.worker_node_machine_name}-${count.index + 1}"
  image_id          = data.openstack_images_image_v2.image.id
  flavor_id         = data.openstack_compute_flavor_v2.flavor.id
  key_pair          = var.key_pair
  availability_zone = "Education"
  user_data         = data.template_file.template_file_cloudinit.rendered
  network {
    port = "${element(openstack_networking_port_v2.ports_worker_nodes.*.id, count.index)}"
  }
}

#--------------------------------------------------------------------
# Resource for creating load balancer instance in OpenStack
#
resource "openstack_compute_instance_v2" "load_balancer" {
  depends_on        = [openstack_networking_router_interface_v2.router_interface]
  name              = local.load_balancer_name
  image_id          = data.openstack_images_image_v2.image.id
  flavor_id         = data.openstack_compute_flavor_v2.flavor.id
  key_pair          = var.key_pair
  availability_zone = "Education"
  user_data         = data.template_file.template_file_cloudinit_lb.rendered
  network {
    port = openstack_networking_port_v2.port_load_balancer.id
  }
}

