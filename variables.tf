variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"

  type = string
}
variable "proxmox_host" {
  description = "Proxmox ssh host"

  type = string
}

variable "proxmox_api_token" {
  description = "API Token"

  type      = string
  sensitive = true
}


variable "proxmox_password" {
  description = "API password"

  type      = string
  sensitive = true
}

variable "proxmox_user" {
  description = "API user"

  type      = string
  sensitive = true
}


variable "node_name" {
  description = "Proxmox node"

  type = string

  default = "pve"
}

variable "internet_bridge" {
  description = "Bridge connected to the Internet"

  type = string

  default = "vmbr0"
}

variable "simple_zone_name" {
  description = "SDN Simple Zone"

  type = string

  default = "class"
}
