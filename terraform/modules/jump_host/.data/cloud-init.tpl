#cloud-config
package_update: true
package_upgrade: true
package_reboot_if_required: true

packages:
  - software-properties-common

locale: "en_US.UTF-8"
timezone: "Europe/Stockholm"

runcmd:
  # ---------------------------------------------------------
  # Clean up unneeded packages and files to free up disk space
  #
  - |
    apt autoremove -y
    apt clean -y
