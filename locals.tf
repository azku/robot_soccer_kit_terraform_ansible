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
          ip        = 11
          memory    = 2048
        }

        kafka = {
          hostname = "kafka"
          ip        = 12
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
          username = "iker"
          password = "ikertxurdi"
        },
        {
          username = "asier"
          password = "asiertxurdi"
        }]
    }

    talde1 = {
      subnet = "10.102.0.0/24"
      containers = {
       
      }
      users  = [
        {
          username = "d.arroyo"
          email = "d.arroyo@ikasle.eus"
          comment = "Danel Arroyo Lopez"
          password = "d.arroyo_txurdi"
        },
        {
          username = "i.beitiarodriguez"
          email = "i.beitiarodriguez@ikasle.eus	"
          comment = "Ibai Beitia Rodriguez"
          password = "i.beitiarodriguez_txurdi"
        },
        {
          username = "u.callemalmierca"
          email = "u.callemalmierca@ikasle.eus"
          comment = "Unai Calle Malmierca"
          password = "u.callemalmierca_txurdi"
        },
        {
          username = "u.canomunoz"
          email = "u.canomunoz@ikasle.eus"
          comment = "Unai Caño Muñoz"
          password = "u.canomunoz_txurdi"
        },
        {
          username = "i.cortesterre"
          email = "i.cortesterre@ikasle.eus"
          comment = "Iker Cortés Terré"
          password = "i.cortesterre_txurdi"
        },
        {
          username = "a.diazbueno"
          email = "a.diazbueno@ikasle.eus"
          comment = "Andoni Díaz Bueno"
          password = "a.diazbueno_txurdi"
        },
        {
          username = "c.gabiola"
          email = "c.gabiola@ikasle.eus"
          comment = "Carmen Gabiola Dominguez"
          password = "c.gabiola_txurdi"
        },
        {
          username = "b.gandiaga"
          email = "b.gandiaga@ikasle.eus"
          comment = "Beñat Gandiaga Valenciano"
          password = "b.gandiaga_txurdi"
        },
        {
          username = "a.garciamesa"
          email = "a.garciamesa@ikasle.eus"
          comment = "Adrian Garcia Mesa"
          password = "a.garciamesa_txurdi"
        },
        {
          username = "m.gonzalezsantos"
          email = "m.gonzalezsantos@ikasle.eus"
          comment = "Miguel Gonzalez Santos"
          password = "m.gonzalezsantos_txurdi"
        },
        {
          username = "b.goni"
          email = "b.goni@ikasle.eus"
          comment = "Beñat Goñi Elorriaga"
          password = "b.goni_txurdi"
        },
        {
          username = "l.idirin"
          email = "l.idirin@ikasle.eus"
          comment = "Luken Idirin Filibi"
          password = "l.idirin_txurdi"
        },
        {
          username = "e.izagirreolivares"
          email = "e.izagirreolivares@ikasle.eus"
          comment = "Ekaitz Izagirre Olivares"
          password = "e.izagirreolivares_txurdi"
        },
        {
          username = "p.jimenezbenito"
          email = "p.jimenezbenito@ikasle.eus"
          comment = "Paula Jimenez Benito"
          password = "p.jimenezbenito_txurdi"
        },
        {
          username = "g.kortabitarte"
          email = "g.kortabitarte@ikasle.eus"
          comment = "Gorka Kortabitarte Gonzalez"
          password = "g.kortabitarte_txurdi"
        },
        {
          username = "ii.oviedo"
          email = "ii.oviedo@ikasle.eus"
          comment = "Ivan Ismael Oviedo"
          password = "ii.oviedo_txurdi"
        },
        {
          username = "joel.rodriguez"
          email = "joel.rodriguez@ikasle.eus"
          comment = "Joel Rodríguez González"
          password = "joel.rodriguez_txurdi"
        },
        {
          username = "o.saenzsanchez"
          email = "o.saenzsanchez@ikasle.eus"
          comment = "Oier Saenz Sanchez"
          password = "o.saenzsanchez_txurdi"
        }

      ]
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
