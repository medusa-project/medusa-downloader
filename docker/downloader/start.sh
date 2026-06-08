#!/usr/bin/env bash
set -e

DEFAULT_STORAGE_LOCATION=/home/downloader/storage
NGINX_HTML_PATH=/var/www/html
NGINX_STANDARD_EXEC=/usr/local/sbin/nginx
NGINX_MODZIP_EXEC=/usr/local/sbin/nginx-modzip
NGINX_DIGEST_USERS_FILE=$NGINX_MODZIP_PREFIX/conf/digest_users

print_usage(){
    echo "Usage: $0 --env-app-settings-file[=ENV_CONFIG_FILE] --db-config-file[=DB_CONFIG_FILE] --secrets-file[=SECRETS_FILE] [--init-db] [--storage[=STORAGE]] [--help]"
}

show_help() {
  print_usage
  echo
  echo "Arguments:                                                                             "
  echo "  --db-config-file              : database config yaml file.                           "
  echo "  --env-app-settings-file       : environment application config yaml file.            "
  echo "  --nginx-digest-users-file     : NGINX digest users file.                             "
  echo "  --nginx-internal-config-file  : NGINX internal config file.                          "
  echo "  --secrets-file                : secrets file.                                        "
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

if [ ! -f "$db_config_file" ]; then
  echo "$db_config_file does not exist"
  echo "missing database config yaml file"
  print_usage
  exit 1
fi

runtime_db_config="/app/config/$(basename $db_config_file)"
if [[ "$db_config_file" != "$runtime_db_config" ]]; then
  ln -sf "$db_config_file" "$runtime_db_config"
fi

if [ ! -f "$env_app_settings_file" ]; then
  echo "$env_app_settings_file does not exist"
  echo "missing environment application config yaml file"
  print_usage
  exit 1
fi

runtime_env_app_settings_file="/app/config/settings/$(basename $env_app_settings_file)"
if [[ "$env_app_settings_file" != "$runtime_env_app_settings_file" ]]; then
  ln -sf "$env_app_settings_file" "$runtime_env_app_settings_file"
fi

if [ ! -f "$secrets_file" ]; then
  echo "$secrets_file does not exist"
  echo "secrets file"
  print_usage
  exit 1
fi

runtime_secrets_file="/app/config/$(basename $secrets_file)"
if [[ "$secrets_file" != "$runtime_secrets_file" ]]; then
  ln -sfv "$secrets_file" "$runtime_secrets_file"
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
ln -sf "$storage" "$NGINX_HTML_PATH"


echo 'starting nginx: standard'
$NGINX_STANDARD_EXEC
$NGINX_STANDARD_EXEC -t || exit 1
echo 'starting nginx - Done'

echo 'starting nginx: modzip'
$NGINX_MODZIP_EXEC
$NGINX_MODZIP_EXEC -t || exit  1
echo 'starting nginx: modzip - Done'

echo 'precompile assets'
bundle exec rails assets:precompile
echo 'precompile assets - Done'

PID_DIR=/app/run
mkdir -p $PID_DIR
DELAYED_JOB_PID_FILE=$PID_DIR/delayed_job.pid
echo  'starting delayed_job'
bundle exec bin/delayed_job -p "$RAILS_ENV" --pid-dir=$PID_DIR restart &
sleep 15
pgrep -f "$RAILS_ENV"/delayed_job | tail -n 1 > $DELAYED_JOB_PID_FILE
echo  'starting delayed_job - Done'

PASSENGER_PID_FILE=$PID_DIR/passanger.pid
echo  'starting Phusion Passenger'
bundle exec passenger start -e "$RAILS_ENV" -d --pid-file=$PASSENGER_PID_FILE
echo  'starting Phusion Passenger - Done'

touch config/puma.rb
cat << EOF > config/puma.rb
# config/puma.rb

log_requests true
quiet false

stdout_redirect '/logs/puma.stdout.log', '/logs/puma.stderr.log', true

EOF

echo 'logs are found in /logs'
bundle exec puma -b unix:///var/run/puma.sock -C config/puma.rb
