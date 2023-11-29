#--------------------------------------------------------------------
# Configure the OpenStack provider
#

terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}

provider "openstack" {
}
