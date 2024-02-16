#--------------------------------------------------------------------
# Variables and locals for jump host module
#

variable "key_pair" {
  description = "Key pair for server authentication"
  type        = string
}

variable "identity_file" {
  description = "Private key path for authentication"
  type        = string
}

variable "router_id" {
  description = "The ID of the router"
  type    = string
}

variable "private_key" {
  description = "The private key to put on the server"
  type    = string
}

variable "jump_host_ip" {
  description = "The IP address of the jump host"
  type    = string
}

variable "external_network_name" {
  description = "External network name"
  type        = string
  default     = "public"
}

variable "subnet_cidr" {
  description = "Subnet CIDR range"
  type        = string
}

variable "subnet_cidr_jump_host" {
  description = "Subnet CIDR range - jump host"
  type        = string
}

variable "flavor_name" {
  description = "Server flavor"
  type        = string
  default     = "c2-r2-d20"
}

variable "image_name" {
  description = "Server image"
  type        = string
  default     = "Ubuntu server 22.04.3"
}

variable "base_name" {
  description = "Base name for resources"
  type        = string
  default     = "k8s"
}

locals {
  network_name            = "${var.base_name}-network"
  subnet_name             = "${var.base_name}-subnet"
  port_name               = "${var.base_name}-port"
  load_balancer_name      = "${var.base_name}-load-balancer"
  port_load_balancer_name = "${var.base_name}-port-load-balancer"
}

variable "control_plane_node_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 1
}

variable "control_plane_node_machine_name" {
  description = "The name of the control plane node machine to create"
  type    = string
  default = "k8s-control-plane"
}

variable "worker_node_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 3
}
variable "worker_node_machine_name" {
  description = "The prefix name of the worker node machine to create"
  type    = string
  default = "k8s-worker"
}
