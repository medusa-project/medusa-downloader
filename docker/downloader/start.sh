#!/usr/bin/env bash

DEFAULT_STORAGE_LOCATION=/home/downloader/storage

print_usage(){
    echo "Usage: $0 --env-app-settings-file[=ENV_CONFIG_FILE] --db-config-file[=DB_CONFIG_FILE] --secrets-file[=SECRETS_FILE] [--init-db] [--storage[=STORAGE]] [--help]"
}

show_help() {
  print_usage
  echo
  echo "Arguments:                                                                             "
  echo "  --db-config-file        : database config yaml file.                                 "
  echo "  --env-app-settings-file : environment application config yaml file.                  "
  echo "  --secrets-file          : secrets file.                  "
  echo "  --init-db               : initializes database before starting server.               "
  echo "  --storage               : path to storage set in yml file.                           "
  echo "                            Defaults to \"$DEFAULT_STORAGE_LOCATION\".                 "
  echo "  --help, -h              : Display this help message.                                 "
}

initialize_db() {
bundle exec rails db:drop db:create db:schema:load
bundle exec rails db:fixtures:load
}


for arg in "$@"; do
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
    show_help
    exit 0
  fi
done

initDb=0
# Parse optional arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --db-config-file=*)
      db_config_file="${1#*=}"
      shift
      ;;
    --db-config-file)
      db_config_file="$2"
      shift
      ;;
    --env-app-settings-file=*)
      env_app_settings_file="${1#*=}"
      shift
      ;;
    --env-app-settings-file)
      env_app_settings_file="$2"
      shift
      ;;
    --secrets-file=*)
      secrets_file="${1#*=}"
      shift
      ;;
    --secrets-file)
      secrets_file="$2"
      shift
      ;;
    --storage=*)
      storage="${1#*=}"
      shift
      ;;
    --storage)
      storage="$2"
      shift 2
      ;;
    --init-db)
      initDb=1
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      show_help
      exit 1
      shift
      ;;
  esac
done

# Set default if storage was not specified
if [[ -z "$storage" ]]; then
  storage="$DEFAULT_STORAGE_LOCATION"
fi

if [ ! -f "$db_config_file" ]; then
  echo "$db_config_file does not exist"
  echo "missing database config yaml file"
  exit 1
fi
ln -sf "$db_config_file" "/app/config/$(basename $db_config_file)"

if [ ! -f "$env_app_settings_file" ]; then
  echo "$env_app_settings_file does not exist"
  echo "missing environment application config yaml file"
  exit 1
fi
ln -sf "$env_app_settings_file" "/app/config/settings/$(basename $env_app_settings_file)"

if [ ! -f "$secrets_file" ]; then
  echo "$secrets_file does not exist"
  echo "secrets file"
  exit 1
fi
ln -sf "$secrets_file" "/app/config/$(basename $secrets_file)"

if [[ ${initDb} -eq 1 ]]; then
    initialize_db
fi

if [ ! -d "$storage" ]; then
  echo "Make $storage"
  mkdir -p "$storage"
fi

echo "Using for storage: $storage"
ln -sf "$storage" /var/www/html/internal

echo 'starting nginx: standard'
nginx
nginx -t || exit 1
echo 'starting nginx - Done'

echo 'starting nginx: modzip'
/usr/local/nginx/sbin/nginx
/usr/local/nginx/sbin/nginx -t || exit  1
echo 'starting nginx: modzip - Done'

mkdir -p tmp/pids

bundle exec puma -b unix:///var/run/puma.sock
