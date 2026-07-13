provider "proxmox" {
  endpoint = var.proxmox_endpoint
  # api_token = var.proxmox_api_token
  password = var.proxmox_password
  username = var.proxmox_user
  insecure = true

  # # ADD THIS SECTION: Tell Terraform exactly where "pve" lives on your network
  # ssh {
  #   agent = true # Or configure password/private_key if you don't use ssh-agent
    
  #   node {
  #     name    = "3ia3dt1"                 # Must match the node_name used in your blocks
  #     address = "62.99.74.141"       # The actual local IP of your Proxmox machine
  #   }
  # }

}
