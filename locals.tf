locals {

  groups = {
    irakasle = {
      subnet = "10.101.0.0/24"
      containers = {
        controller = {
          hostname = "gamecontroller"
          ip        = 10
          memory    = 1024
        }

        postgres = {
          hostname = "postgres"
          ip        = 20
          memory    = 2048
        }
      }
      users  = [{
          username = "jon"
          password = "jontxurdi"
        },
        {
          username = "inaki"
          password = "inakitxurdi"
        },
        {
          username = "maider"
          password = "maidertxurdi"
        },
        {
          username = "asier"
          password = "asiertxurdi"
        }]
    }

    talde1 = {
      subnet = "10.102.0.0/24"
      containers = {
        controller = {
          hostname = "gamecontroller"
          ip        = 10
          memory    = 1024
        }

        postgres = {
          hostname = "postgres"
          ip        = 20
          memory    = 2048
        }
      }
      users  = [{
          username = "carol"
          password = "password3"
        },
        {
          username = "dave"
          password = "password4"
        }]
    }
  }

  # Extract network metadata per group
  networks = {
    for name, cfg in local.groups : name => {
      cidr = cfg.subnet

      # assume /24 only for now (we can generalize later)
      gateway = cidrhost(cfg.subnet, 1)

      dhcp_start = cidrhost(cfg.subnet, 100)
      dhcp_end   = cidrhost(cfg.subnet, 200)
    }
  }

  # Helper loop to flatten the users: creates a unique key like "team1-alice"
   flat_users = merge([
    for team_name, team_data in local.groups : {
      for user in team_data.users : "${team_name}-${user.username}" => {
        username = user.username
        password = user.password
        team     = team_name
      }
    }
   ]...)

   # Flatten containers
  flat_containers = merge([
    for team_name, team_data in local.groups : {
      for container_name, container in team_data.containers :
      "${team_name}-${container_name}" => merge(container, {
        team = team_name
        name = container_name
        subnet = team_data.subnet
      })
    }
  ]...)


  container_ips = {
    for team, group in local.groups :
    team => cidrhost(group.subnet, 10)
  }

}
