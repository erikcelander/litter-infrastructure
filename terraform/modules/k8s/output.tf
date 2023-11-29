#--------------------------------------------------------------------
# Outputs
#

output "load_balancer_ips" {
  description = "Load balancer's IP addresses"
  value       = "${openstack_networking_floatingip_v2.floatingip.address}, ${openstack_compute_instance_v2.load_balancer.access_ip_v4}"
}

output "control_plane_ips" {
    description = "IP addresses of the control plane nodes. Index 1 is the primary control plane node."
    value = "${openstack_compute_instance_v2.control_planes.*.access_ip_v4}"
}

output "worker_ips" {
    description = "IP addresses of the worker nodes."
    value = "${openstack_compute_instance_v2.workers.*.access_ip_v4}"
}
