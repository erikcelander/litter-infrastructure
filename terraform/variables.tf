#--------------------------------------------------------------------
# Variables and locals for the main module
#

variable "external_network_name" {
  description = "External network name"
  type        = string
  default     = "public"
}

variable "identity_file" {
  description = "The path to the private key to use for authentication"
  type    = string
}

variable "jump_host_cidr" {
  description = "Subnet CIDR range"
  type        = string
  default     = "192.168.4.0/24"
}

variable "k8s_cidr" {
  description = "Subnet CIDR range"
  type        = string
  default     = "192.168.5.0/24"
}

variable "key_pair" {
  description = "The name of the key pair to put on the server"
  type    = string
}

variable "image_name" {
  description = "Server image"
  type        = string
  default     = "Ubuntu server 22.04.3"
}
