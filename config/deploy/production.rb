# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

# server 'example.com', user: 'deploy', roles: %w{app db web}, my_property: :my_value
# server 'example.com', user: 'deploy', roles: %w{app web}, other_property: :other_value
# server 'db.example.com', user: 'deploy', roles: %w{db}

set :home, '/home/downloader'
set :deploy_to, "#{fetch(:home)}/medusa-downloader-capistrano"
set :rails_env, 'production'
#set :bundle_path, nil
set :ssh_options, {
  forward_agent: true,
  auth_methods: ["publickey"],
  keys: ["#{Dir.home}/.ssh/medusa_prod.pem"]
}

set :linked_files, %w(config/settings/production.local.yml)

server 'aws-downloader-prod.library.illinois.edu', user: 'downloader', roles: %w(web app db), primary: true
ask :branch, proc {`git rev-parse --abbrev-ref HEAD`.chomp}.call

set :keep_releases, 5
