#!/usr/bin/env bash

set -e

DB_PREFIX=prestashop
DOMAIN=

DO_SSL=0
#MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"
MYSQL_USER_NAME="${MYSQL_USER_NAME:-}"
MYSQL_USER_PASSWORD="${MYSQL_USER_PASSWORD:-}"

HTTPD_WWW_ROOT_DIR=/var/www
HTTPD_LOG_ROOT_DIR=/var/log/apache2
HTTPD_CONF="/etc/nginx/nginx.conf"
HTTPD_SITES_AVAILABLE_DIR="/etc/nginx/sites-available"
HTTPD_SITES_ENABLED_DIR="/etc/nginx/sites-enabled"

CLEANUP_FILES_ON_EXIT=()

#trap 'cleanup' EXIT
trap 'rm -f "${CLEANUP_FILES_ON_EXIT[@]}"' EXIT

declare APT_PACKAGES=(
  jq
  mariadb-server
  nginx
  php
  php-cli
  php-curl
  php-fpm
  php-gd
  php-json
  php-intl
  php-mbstring
  php-mysql
  php-xml
  php-zip
  python3-certbot-nginx
  unzip
)

declare PIP_REQUIREMENTS=(
  ansible
)

function usage() {
  (
    echo "$(basename "$0") <args...>"
    echo
    echo "Required Arguments:"
    # echo "  --mysql-root-password <password>"
    echo "  --mysql-user <username>"
    echo "  --mysql-password <password>"
    echo "  --domain <domain>"
    echo
    echo "Optional Arguments:"
    echo "  --ssl"
  ) >&2
}

# Remove all the files in the CLEANUP_FILES_ON_EXIT array.
function cleanup() {
  rm -f "${CLEANUP_FILES_ON_EXIT[@]}"
}

# Get a temporary file and add it to the stack of files to be removed when the script exits.
function get_tmpfile() {
  local filename="$(mktemp --suffix="$1")" ; shift
  CLEANUP_FILES_ON_EXIT+=("${filename}")
  echo "${filename}"
}

# Output the path of the virtual host's contents.
function get_vhost_path() {
  local domain="$1" ; shift
  echo "${HTTPD_WWW_ROOT_DIR}/${domain}"
}

# Generate a VirtualHost directive for httpd.
function write_httpd_conf() {
  local domain="$1" ; shift

  local httpd_conf="${HTTPD_SITES_AVAILABLE_DIR}/${domain}.conf"
  local vhost_dir="$(get_vhost_path "$(echo ${domain} | tr . _)")"
  local tmpfile="$(get_tmpfile .conf)"

  # Generate the nginx server block for the vhost.
  cat >"${tmpfile}" <<EOF
server {
  listen 80;
  listen [::]:80;

  server_name ${domain}

  root /var/www/${domain}/html;
  index index.php index.html;

  location / {
    try_files $uri $uri/ =404;
  }
}
EOF

  sudo mv "${tmpfile}" "${httpd_conf}"
#EOF

}

function install_packages() {
  sudo apt update
  sudo apt -y upgrade
  sudo apt -y install "${APT_PACKAGES[@]}"
}

function install_pip_requirements() {
  pip install "${PIP_REQUIREMENTS[@]}"
}

function install_doctl() {
  curl 'https://github.com/digitalocean/doctl/releases/download/v1.101.0/doctl-1.101.0-linux-amd64.tar.gz' -O /tmp/doctl.tar.gz
  pushd /tmp >/dev/null
  tar xf doctl.tar.gz
  sudo mv doctl /usr/local/bin
  popd >/dev/null
}

function setup_php_ini() {
  local php_ini_file="$(php -i | grep -E '^Loaded.*php.ini$' | awk '{ print $5; }')"
  sudo sed -i 's/memory_limit =.*/memory_limit = 128M/;' "${php_ini_file}"
  sudo sed -i 's/upload_max_filesize =.*/upload_max_filesize = 32M/;' "${php_ini_file}"
}

# Download and install PrestaShop.
function install_prestashop() {
  local domain="$1" ; shift

  local install_dir="$(get_vhost_path "$(echo "${domain}" | tr . _)")"

  pushd "$(dirname "$(mktemp -d)")" >/dev/null

  # Download PrestaShop.
  local url="$(
    curl -s https://api.github.com/repos/PrestaShop/PrestaShop/releases/latest | \
    jq --raw-output '.assets[].browser_download_url' | \
    grep -E '\.zip$'
  )" 

  local filename="$(basename "${url}")"
  CLEANUP_FILES_ON_EXIT+=("$(readlink -f "${filename}")")

  echo "Downloading ${filename}..."
  curl -LO "${url}"

  # Install webapp into proper vhost directory.
  sudo unzip "${filename}" -d "${install_dir}"
  sudo chown -R www-data: "${install_dir}"

  popd >/dev/null
}

# Setup MySQL root user.
function setup_mysql_root_user() {
  local root_password="$1" ; shift

  local filename="$(get_tmpfile .sql)"

  cat >"${filename}" <<EOF
ALTER USER root@\`localhost\`
  IDENTIFIED VIA mysql_native_password USING '${root_password}';
EOF

  sudo mysql <"${filename}"
  sudo mysql_secure_installation
}

function setup_mysql_user() {
  local username="$1" ; shift
  local password="$1" ; shift
  local hostname="$1" ; shift

  local filename="$(get_tmpfile .sql)"

  echo "Creating user ${username}@${hostname} if they do not exist."

  cat >"${filename}" <<EOF
CREATE USER IF NOT EXISTS \`${username}\`@\`${hostname}\`;

ALTER USER \`${username}\`@\`${hostname}\`
  IDENTIFIED BY '${password}';
EOF

  sudo mysql <"${filename}"
}

function setup_mysql_database_and_add_user() {
  local username="$1" ; shift
  local hostname="$1" ; shift
  local database="$1" ; shift

  local filename="$(get_tmpfile .sql)"

  echo "Creating database ${database} if it does not exist and granting full permissions to ${username}@${hostname}."

  cat >"${filename}" <<EOF
CREATE DATABASE IF NOT EXISTS \`${database}\`;

GRANT ALL PRIVILEGES
  ON \`${database}\`.*
  TO \`${username}\`@\`${hostname}\`;
EOF

  sudo mysql <"${filename}"
}

function main() {
  local database="${DB_PREFIX}__$(echo "${DOMAIN}" | tr . _)"

  install_packages
  install_pip_requirements
  install_doctl
  setup_php_ini
  install_prestashop "${DOMAIN}"

  # setup_mysql_root_user "${MYSQL_ROOT_PASSWORD}"
  setup_mysql_user "${MYSQL_USER_NAME}" "${MYSQL_USER_PASSWORD}" localhost
  setup_mysql_database_and_add_user "${MYSQL_USER_NAME}" localhost "${database}"

  # Setup Prestashop.
  write_httpd_conf "${DOMAIN}"

  sudo ln -s "${HTTPD_SITES_AVAILABLE_DIR}/${DOMAIN}.conf" "${HTTPD_SITES_ENABLED_DIR}/${DOMAIN}.conf"

  sed -i 's/# (server_names_hash_bucket_size)/\1/g;' "${NGINX_CONF}"

  sudo nginx -t
  sudo systemctl restart nginx

  local scheme=http
  if test $DO_SSL -eq 1 ; then
    sudo certbot --apache -d "$DOMAIN"
    scheme=https
  fi

  echo "Your PrestaShop is installed! You can now go to ${scheme}://${DOMAIN}"
}

while test $# -ne 0 ; do
  case $1 in
#    --mysql-root-password)
#      MYSQL_ROOT_PASSWORD="$2"
#      shift
#      ;;
    --mysql-user)
      MYSQL_USER_NAME="$2"
      shift
      ;;
    --mysql-password)
      MYSQL_USER_PASSWORD="$2"
      shift
      ;;
    --domain)
      DOMAIN="$2"
      shift
      ;;
    --ssl)
      DO_SSL=1
      ;;
    *)
      usage
      exit 0
  esac

  shift
done

# if test -z "${MYSQL_ROOT_PASSWORD}" ; then
#   echo "--mysql-root-password missing; see --help"
#   exit 1
# fi
if test -z "${MYSQL_USER_NAME}" ; then
  echo "--mysql-user missing; see --help"
  exit 1
fi
if test -z "${MYSQL_USER_PASSWORD}" ; then
  echo "--mysql-user-password missing; see --help"
  exit 1
fi
if test -z "${DOMAIN}" ; then
  echo "--domain missing; see --help"
  exit 1
fi

#set -x
main
