#############################################
# 1. RESOURCE POOLS (One per team)
#############################################
resource "proxmox_virtual_environment_pool" "team_pool" {
  for_each = local.groups
  
  pool_id  = "${each.key}-pool"
  comment  = "Isolated lab space for ${each.key}"
}

#############################################
# 2. PROXMOX GROUPS (One per team)
#############################################
resource "proxmox_virtual_environment_group" "team_group" {
  for_each = local.groups
  
  group_id = "${each.key}-group"
  comment  = "Access group for ${each.key}"
}

#############################################
# 3. PROXMOX USERS (Iterating over flat_users)
#############################################
resource "proxmox_virtual_environment_user" "lab_users" {
  for_each = local.flat_users

  # This creates users in the local Proxmox realm (e.g., alice@pve)
  user_id  = "${each.value.username}@pve" 
  comment  = "Lab user for ${each.value.team}"
  password = "${each.value.password}" # In production, use a secret variable or vault
  
  # Automatically assign the user to their team's group
  groups   = [proxmox_virtual_environment_group.team_group[each.value.team].group_id]
}
resource "proxmox_virtual_environment_user" "lab_pam_users" {
  for_each = local.flat_users

  user_id  = "${each.value.username}@pam"

  comment  = "SSH user for ${each.value.team}"

  password = each.value.password
  depends_on = [
    null_resource.pam_users
  ]
}
resource "null_resource" "pam_users" {

  triggers = {
    users = jsonencode(local.flat_users)
  }

  provisioner "local-exec" {
    command = <<-EOF
      ssh root@${var.proxmox_host} 'bash -s' <<'REMOTE_SCRIPT'

      %{ for _, user in local.flat_users ~}
      id "${user.username}" >/dev/null 2>&1 || useradd -m "${user.username}"
      echo "${user.username}:${user.password}" | chpasswd
      %{ endfor ~}

      REMOTE_SCRIPT
    EOF
  }
}



#############################################
# 4. ACL PERMISSIONS (The Magic Isolator)
#############################################
resource "proxmox_acl" "pool_access" {
  for_each = local.groups

  # Path points strictly to that team's resource pool
  path      = "/pool/${proxmox_virtual_environment_pool.team_pool[each.key].pool_id}"
  
  # Grant permissions to the team's group
  group_id  = proxmox_virtual_environment_group.team_group[each.key].group_id
  
  # 'PVEVMAdmin' allows them to manage VMs/Containers inside their pool
  role_id   = "PVEVMAdmin" 
}
#############################################
# SDN SIMPLE ZONE (base for all networks)
#############################################

resource "proxmox_sdn_zone_simple" "ia3d" {
  id = var.simple_zone_name
  ipam = "pve"
  dhcp = "dnsmasq"
}

#############################################
# SDN APPLIER (critical step)
#############################################


resource "proxmox_sdn_vnet" "vnet" {

  for_each = local.groups

  id   = each.key
  zone = proxmox_sdn_zone_simple.ia3d.id
}
resource "proxmox_sdn_subnet" "subnet" {

  for_each = local.groups


  vnet = proxmox_sdn_vnet.vnet[each.key].id

  cidr = each.value.subnet

  gateway = local.networks[each.key].gateway

  snat = true

  dhcp_range = {
    start_address = local.networks[each.key].dhcp_start
    end_address   = local.networks[each.key].dhcp_end
  }
}
resource "proxmox_sdn_applier" "apply" {

  depends_on = [
    proxmox_sdn_zone_simple.ia3d,
    proxmox_sdn_vnet.vnet,
    proxmox_sdn_subnet.subnet
  ]
}


resource "proxmox_virtual_environment_container" "my_first_ct" {
  
  for_each = local.flat_containers
  node_name    = var.node_name
  description  = "Managed by Terraform"
  pool_id   = proxmox_virtual_environment_pool.team_pool[each.value.team].pool_id
  unprivileged = true
  depends_on = [
    proxmox_sdn_subnet.subnet
  ]
  start_on_boot = true
   features {
    nesting = true
  }

  # Define the OS Template (Needs to be pre-downloaded on your Proxmox storage)
  operating_system {
    template_file_id = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
    type             = "ubuntu"
  }
  initialization {
    hostname = "${each.value.team}-${each.value.hostname}"
    user_account {
      password = "txurdi"
      keys = [
        file("~/.ssh/hadoop_key_pub")
      ]
    }
    dns {
      domain  = "local"
      servers = ["1.1.1.1"]
    }
    ip_config {
      ipv4 {
        address = "${cidrhost(each.value.subnet, each.value.ip)}/24"
        gateway = cidrhost(each.value.subnet, 1)
      }
    }
  }

  # Root Filesystem (disk block is required)
  disk {
    datastore_id = "local-lvm"
    size         = 4 # in GiB
  }

  # Network Interface (example for DHCP)
   # Network
  network_interface {
    name   = "eth0"
    bridge = proxmox_sdn_vnet.vnet[each.value.team].id
    firewall = true
  }
}

resource "null_resource" "install_openssh" {
  for_each = proxmox_virtual_environment_container.my_first_ct

  depends_on = [
    proxmox_virtual_environment_container.my_first_ct
  ]

provisioner "local-exec" {
    command = <<EOF
ssh root@${var.proxmox_host} "
pct exec ${each.value.vm_id} -- bash -c '
apt-get update &&
DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server &&
systemctl enable ssh &&
systemctl start ssh
'"
EOF
  }
}
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/inventory.ini"

  content = <<EOF
[controllers]
%{ for _, c in local.flat_containers ~}
%{ if c.name == "controller" ~}
${c.team}-${c.name} ansible_host=${cidrhost(c.subnet, 10)}
%{ endif ~}
%{ endfor ~}

[postgres]
%{ for _, c in local.flat_containers ~}
%{ if c.name == "postgres" ~}
${c.team}-${c.name} ansible_host=${cidrhost(c.subnet, 20)}
%{ endif ~}
%{ endfor ~}

[all:vars]
ansible_user=root
EOF
}

resource "proxmox_virtual_environment_vm" "desktop-pc" {
  for_each = local.groups

  name      = "${each.key}-desktop2"
  node_name = var.node_name

  pool_id = proxmox_virtual_environment_pool.team_pool[each.key].pool_id

  depends_on = [
    proxmox_sdn_subnet.subnet
  ]
  clone {
    vm_id = 9000
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096
  }
  network_device {
    bridge = proxmox_sdn_vnet.vnet[each.key].id
    model  = "virtio"
  }

  initialization {
    user_account {
      username = "student"
      password = "proba"
      keys = [
        file("~/.ssh/hadoop_key_pub")
      ]
    }

    ip_config {
      ipv4 {
        address = "${cidrhost(each.value.subnet,30)}/24"
        gateway = cidrhost(each.value.subnet,1)
      }
    }

    dns {
      servers = ["1.1.1.1"]
    }
  }

  agent {
    enabled = true
  }

  started = true
}
