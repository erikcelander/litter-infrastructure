#--------------------------------------------------------------------
# Output IP Addresses
#

output "jump_host_ips" {
    description = "IP addresses of the jump host."
    value = module.jump_host.jump_host_ips
}

output "load_balancer_ips" {
    description = "IP addresses of the load balancer."
    value = module.k8s.load_balancer_ips
}

output "control_plane_ips" {
    description = "IP addresses of the control plane nodes. Index 1 is the primary control plane node."
    value = module.k8s.control_plane_ips
}

output "worker_ips" {
    description = "IP addresses of the worker nodes."
    value = module.k8s.worker_ips
}
