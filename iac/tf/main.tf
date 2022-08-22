# https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs
resource "digitalocean_project" "playground" {
  name        = "playground"
  description = "A project to represent development resources."
  purpose     = "Web Application"
  environment = "Development"
  resources = [
    digitalocean_database_cluster.wordpress.urn
  ]
}

# Create a mysql cluster
resource "digitalocean_database_cluster" "wordpress" {
  name       = "wordpress"
  engine     = "mysql"
  version    = "8"
  size       = "db-s-1vcpu-1gb"
  region     = "nyc3"
  node_count = 1
}

# Create a db inside the cluster
resource "digitalocean_database_db" "wordpress" {
  cluster_id = digitalocean_database_cluster.wordpress.id
  name = "wordpress"
}

# Create a k8s cluster
data "digitalocean_kubernetes_versions" "idbm" {
  version_prefix = "1.23."
}

resource "digitalocean_kubernetes_cluster" "idbm" {
  name   = "idbm"
  region = "nyc3"
  auto_upgrade = true
  version = data.digitalocean_kubernetes_versions.idbm.latest_version

  maintenance_policy {
    start_time = "04:00"
    day        = "sunday"
  }

  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-2gb"
    node_count = 1
    # auto_scale = true
    # min_nodes = 1
    # max_nodes = 3

    taint {
      key    = "workloadKind"
      value  = "database"
      effect = "NoSchedule"
    }
  }
}
