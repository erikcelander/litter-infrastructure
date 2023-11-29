#--------------------------------------------------------------------
# Variables and locals for jump host module
#

# Variables related to server configuration
variable "flavor_name" {
  description = "Server flavor"
  type        = string
  default     = "c1-r1-d10"
}

variable "image_name" {
  description = "Server image"
  type        = string
  default     = "Ubuntu server 22.04.3"
}

variable "server_name" {
  description = "Jump host server name"
  type        = string
  default     = "jump-host"
}

variable "key_pair" {
  description = "Key pair for server authentication"
  type        = string
}

variable "identity_file" {
  description = "Private key path for authentication"
  type        = string
}

# variable "private_key_openssh" {
#   description = "Private SSH key in OpenSSH format"
#   type        = string
#   sensitive   = true
# }

variable "private_key_pem" {
  description = "Private SSH key in PEM format"
  type        = string
  sensitive   = true
}

# Variables related to network configuration
variable "external_network_name" {
  description = "External network name"
  type        = string
  default     = "public"
}

variable "subnet_cidr" {
  description = "Subnet CIDR range"
  type        = string
}

# Variables related to resource naming
variable "base_name" {
  description = "Base name for resources"
  type        = string
  default     = "jump-host"
}

locals {
  network_name = "${var.base_name}-network"
  subnet_name  = "${var.base_name}-subnet"
  port_name    = "${var.base_name}-port"
  router_name  = "${var.base_name}-router"
}
