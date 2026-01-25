# terraform/variables.tf

variable "vm_count" {
  description = "Number of VM nodes to create"
  type        = number
  default     = 8
}

variable "vm_name" {
  description = "The hostname for the CI/CD node"
  type        = string
  default     = "testnode"
}

variable "cpus" {
  description = "Number of virtual CPUs"
  type        = number
  default     = 1
}

variable "memory" {
  description = "RAM allocation in MiB"
  type        = string
  default     = "2048 mib"
}

variable "vagrant_box" {
  description = "Vagrant box to use for VMs"
  type        = string
  default     = "ubuntu/jammy64"  # Ubuntu 22.04 LTS
  # Other options:
  # "ubuntu/focal64"  # Ubuntu 20.04 LTS
  # "ubuntu/bionic64" # Ubuntu 18.04 LTS
}

variable "host_network_interface" {
  description = "The name of the Host-Only network adapter (not used with Vagrant managed networking)"
  type        = string
  default     = "VirtualBox Host-Only Ethernet Adapter"
}
