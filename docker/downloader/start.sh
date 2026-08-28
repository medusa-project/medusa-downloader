#!/usr/bin/env bash
set -e

DEFAULT_STORAGE_LOCATION=/home/downloader/storage
NGINX_HTML_PATH=/var/www/html
NGINX_STANDARD_EXEC=/usr/local/sbin/nginx
NGINX_MODZIP_EXEC=/usr/local/sbin/nginx-modzip
NGINX_DIGEST_USERS_FILE=$NGINX_MODZIP_PREFIX/conf/digest_users

print_usage(){
    echo "Usage: $0 --env-app-key-var[=ENV_SECRET_KEY] [--init-db] [--storage[=STORAGE]] [--help]"
}

show_help() {
  print_usage
  echo
  echo "Arguments:                                                                             "
  echo "  --env-app-secret-key-var      : environment application key variable.                "
  echo "  --nginx-digest-users-file     : NGINX digest users file.                             "
  echo "  --nginx-internal-config-file  : NGINX internal config file.                          "
  echo "  --init-db                     : initializes database before starting server.         "
  echo "  --storage                     : path to storage set in yml file.                     "
  echo "                                  Defaults to \"$DEFAULT_STORAGE_LOCATION\".           "
  echo "  --help, -h                    : Display this help message.                           "
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
    --env-app-secret-key-var=*)
      env_app_secret_key_var="${1#*=}"
      shift
      ;;
    --env-app-secret-key-var)
      env_app_secret_key_var="$2"
      shift
      ;;
    --storage=*)
      storage="${1#*=}"
      shift
      ;;
    --nginx-internal-config-file)
      nginx_internal_config_file="$2"
      shift
      ;;
    --nginx-internal-config-file=*)
      nginx_internal_config_file="${1#*=}"
      shift
      ;;
    --nginx-digest-users-file=*)
      nginx_digest_users="${1#*=}"
      shift
      ;;
    --nginx-digest-users-file)
      nginx_digest_users="$2"
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

# if [ -z "$env_app_secret_key_var" ]; then
#   echo "missing environment application secret key variable"
#   print_usage
#   exit 1
# fi

if [[ -n "$env_app_secret_key_var" ]]; then
  env_app_key_file="/app/config/credentials/$RAILS_ENV.key"
  env_key_var="$RAILS_ENV"_key
  env_key_val=$(jq -r ".${env_key_var}" <<< "${!env_app_secret_key_var}") 
  echo $env_key_val > "$env_app_key_file"
fi

if [[ -v nginx_internal_config_file ]]; then
  runtime_nginx_internal_config_file="$NGINX_MODZIP_PREFIX/conf/$(basename $nginx_internal_config_file)"
  if [[ "$nginx_internal_config_file" != "$runtime_nginx_internal_config_file" ]]; then
    ln -sfv "$nginx_internal_config_file" "$runtime_nginx_internal_config_file"
    echo "using $runtime_nginx_internal_config_file for internal config file"
  fi
fi

if [[ -v nginx_digest_users ]]; then
  if [[ "$nginx_digest_users" != "$NGINX_DIGEST_USERS_FILE" ]]; then
    cp "$nginx_digest_users" "$NGINX_DIGEST_USERS_FILE"
  fi
fi



if [[ ${initDb} -eq 1 ]]; then
    initialize_db
fi

if [ ! -d "$storage" ]; then
  echo "Make $storage"
  mkdir -p "$storage"
fi

echo "Using for storage: $storage"
rm -rf "$NGINX_HTML_PATH"
ln -s "$storage" "$NGINX_HTML_PATH"


echo 'starting nginx: standard'
$NGINX_STANDARD_EXEC &
$NGINX_STANDARD_EXEC -t || exit 1
echo 'starting nginx - Done'

echo 'starting nginx: modzip'
$NGINX_MODZIP_EXEC
$NGINX_MODZIP_EXEC -t || exit  1
echo 'starting nginx: modzip - Done'

echo 'precompile assets'
bundle exec rails assets:precompile
echo 'precompile assets - Done'


echo  'starting delayed_job'
while true; do
  bundle exec rails jobs:work
  echo "delayed_job exited, restarting in 5 seconds..."
  sleep 5
done &
echo  'starting delayed_job - Done'

RUN_DIR=/app/run
mkdir -p $RUN_DIR
PASSENGER_PID_FILE=$RUN_DIR/passenger.pid
echo 'logs are found in /logs'
echo  'starting Phusion Passenger'

bundle exec passenger start -e "$RAILS_ENV" --pid-file=$PASSENGER_PID_FILE
echo  'starting Phusion Passenger - Done'
