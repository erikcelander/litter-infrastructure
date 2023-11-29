#--------------------------------------------------------------------
# Create a network for the infrastructure
#
resource "openstack_networking_network_v2" "network" {
  name = local.network_name
}

#--------------------------------------------------------------------
# Create a subnet within the network
#
resource "openstack_networking_subnet_v2" "subnet" {
  name       = local.subnet_name
  network_id = openstack_networking_network_v2.network.id
  cidr       = var.subnet_cidr
  ip_version = 4
}

#--------------------------------------------------------------------
# Attach the subnet to the router
#
resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id = var.router_id
  subnet_id = openstack_networking_subnet_v2.subnet.id
}

#--------------------------------------------------------------------
# Create a security group to allow SSH traffic (22) from the jump host network
#
resource "openstack_networking_secgroup_v2" "secgroup_ssh_from_jump_host" {
  name        = "jump-host-ssh-private"
  description = "Allow SSH traffic (22) from the jump host network"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_ssh_from_jump_host" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.subnet_cidr_jump_host
  security_group_id = openstack_networking_secgroup_v2.secgroup_ssh_from_jump_host.id
}

#--------------------------------------------------------------------
# Create a security group, and rules for the load balancer
#
resource "openstack_networking_secgroup_v2" "secgroup_load_balancer" {
  name        = "k8s-load-balancer"
  description = "Allow HTTP traffic to the worker nodes"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_from_public" {
  for_each = toset(["80", "443"])

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value
  port_range_max    = each.value
  remote_ip_prefix  = "0.0.0.0/0" 
  security_group_id = openstack_networking_secgroup_v2.secgroup_load_balancer.id
}


# #--------------------------------------------------------------------
# # Create a security group, and rules for the control plane nodes
# #
# resource "openstack_networking_secgroup_v2" "secgroup_control_plane" {
#   name        = "k8s-control-plane-node"
#   description = "Allow HTTP traffic to the control plane nodes"
# }

# resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_from_lb" {
#   for_each = toset(["80", "443"])

#   direction         = "ingress"
#   ethertype         = "IPv4"
#   protocol          = "tcp"
#   port_range_min    = each.value
#   port_range_max    = each.value
#   remote_group_id   = openstack_networking_secgroup_v2.secgroup_load_balancer.id
#   security_group_id = openstack_networking_secgroup_v2.secgroup_control_plane.id
# }

#--------------------------------------------------------------------
# Create a security group, and rules for the worker nodes
#
resource "openstack_networking_secgroup_v2" "secgroup_worker" {
  name        = "k8s-worker-node"
  description = "Allow HTTP traffic to the worker nodes"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_from_cp" {
  for_each = toset(["80", "443"])

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value
  port_range_max    = each.value
  remote_group_id   = openstack_networking_secgroup_v2.secgroup_load_balancer.id
  security_group_id = openstack_networking_secgroup_v2.secgroup_worker.id
}

#--------------------------------------------------------------------
# Create a security group, and rules for 22/80/443/5050 from everywhere
#
resource "openstack_networking_secgroup_v2" "secgroup_public" {
  name        = "k8s-public"
  description = "Allow traffic to the nodes from everywhere"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_from_everywhere" {
  for_each = toset(["22", "80", "443", "5050"])

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value
  port_range_max    = each.value
  remote_ip_prefix  = "0.0.0.0/0" 
  security_group_id = openstack_networking_secgroup_v2.secgroup_public.id
}

#--------------------------------------------------------------------
# Create a ports for control plane nodes network connections
#
resource "openstack_networking_port_v2" "ports_control_plane_nodes" {
  count              = var.control_plane_node_count
  name               = format("%s-control-plane-%d", local.port_name, count.index)
  network_id         = openstack_networking_network_v2.network.id
  security_group_ids = [
    data.openstack_networking_secgroup_v2.secgroup_default.id,
    openstack_networking_secgroup_v2.secgroup_ssh_from_jump_host.id,
    # openstack_networking_secgroup_v2.secgroup_control_plane.id
    openstack_networking_secgroup_v2.secgroup_public.id
  ]
  admin_state_up     = "true"
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.subnet.id
  }
}

#--------------------------------------------------------------------
# Create ports for worker nodes network connections
#
resource "openstack_networking_port_v2" "ports_worker_nodes" {
  count              = var.worker_node_count
  name               = format("%s-worker-%d", local.port_name, count.index)
  network_id         = openstack_networking_network_v2.network.id
  security_group_ids = [
    data.openstack_networking_secgroup_v2.secgroup_default.id,
    openstack_networking_secgroup_v2.secgroup_ssh_from_jump_host.id,
    openstack_networking_secgroup_v2.secgroup_worker.id,
    openstack_networking_secgroup_v2.secgroup_public.id
  ]
  admin_state_up     = "true"
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.subnet.id
  }
}

#--------------------------------------------------------------------
# Create port for load balancer network connections
#
resource "openstack_networking_port_v2" "port_load_balancer" {
  name               = local.port_load_balancer_name
  network_id         = openstack_networking_network_v2.network.id
  security_group_ids = [
    data.openstack_networking_secgroup_v2.secgroup_default.id,
    openstack_networking_secgroup_v2.secgroup_ssh_from_jump_host.id,
    openstack_networking_secgroup_v2.secgroup_load_balancer.id
  ]
  admin_state_up     = "true"
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.subnet.id
  }
}

#--------------------------------------------------------------------
# Allocate a floating IP for external access
#
resource "openstack_networking_floatingip_v2" "floatingip" {
  pool = "public"
}

#--------------------------------------------------------------------
# Associate the floating IP with the load balancer port
#
resource "openstack_networking_floatingip_associate_v2" "floatingip_association" {
  depends_on = [ 
    openstack_networking_floatingip_v2.floatingip,
    openstack_networking_port_v2.port_load_balancer,
    openstack_networking_router_interface_v2.router_interface
  ]
  floating_ip = openstack_networking_floatingip_v2.floatingip.address
  port_id     = openstack_networking_port_v2.port_load_balancer.id
}
