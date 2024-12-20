require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MedusaDownloader
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0


    # CONFIG = YAML.load(ERB.new(File.read(File.join(Rails.root, 'config', 'medusa_downloader.yml'))).result)[Rails.env].with_indifferent_access

    attr_accessor :storage_roots

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    config.active_job.queue_adapter = :delayed_job
    config.action_mailer.perform_caching = false
    config.action_mailer.delivery_method = :smtp
    config.active_record.legacy_connection_handling = false

    config.action_mailer.smtp_settings = {
      address: "smtp.sparkpostmail.com",
      port: 587,
      enable_starttls_auto: true,
      user_name: "SMTP_Injection",
      password: Settings.smtp[:password],
      domain: 'library.illinois.edu '
    }

  end
end
