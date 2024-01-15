# https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs
resource "digitalocean_project" "idbm" {
  name        = "Interior Design by Maryam"
  description = "A project to represent development resources."
  purpose     = "Website or blog"
  environment = "Development"
  resources = [
    digitalocean_database_cluster.prestashop.urn,
    digitalocean_droplet.yourinterior_space.urn
  ]
}

# Create a mysql cluster.
#
# See https://docs.digitalocean.com/reference/api/api-reference/#tag/Databases
# for information on how to see database slugs.
#
# tl;dr: Use `doctl databases options`.
resource "digitalocean_database_cluster" "mysql" {
  name       = "wordpress"
  engine     = "mysql"
  version    = "8"
  size       = "db-s-1vcpu-1gb"
  region     = "nyc3"
  node_count = 1
}

# Create a prestashop inside the cluster.
resource "digitalocean_database_db" "prestashop" {
  cluster_id = digitalocean_database_cluster.mysql.id
  name       = "prestashop"
}

# Create a user inside the database.
resource "digitalocean_database_user" "prestashop_user" {
  cluster_id = digitalocean_database_cluster.mysql.id
  name       = "prestashop"
  role       = "primary"
  password   = "prestashop-pw"  # TODO put this in a tfvars file or Vault
}

# Create an app container.
resource "digitalocean_droplet" "yourinterior_space" {
  image  = "ubuntu-22-04-x64"
  name   = "yourinterior.space"
  region = "nyc-3"
  size   = "s-1vcpu-1gb"
}

resource "digitalocean_domain" "yourinterior_space_cname" {
  name   = "yourinterior.space"
}
