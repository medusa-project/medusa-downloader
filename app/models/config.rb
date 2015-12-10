require 'singleton'

class Config < Object
  include Singleton

  attr_accessor :config

  def initialize
    self.config = YAML.load(ERB.new(File.read(File.join(Rails.root, 'config', 'medusa_downloader.yml'))).result)[Rails.env].with_indifferent_access
  end

  def self.method_missing(message, *args)
    instance.send(message, *args)
  end

  def admin_email
    config[:admin_email]
  end

  def smtp
    config[:smtp]
  end

  def amqp
    config[:amqp].symbolize_keys
  end

  def nginx_url
    config[:nginx_url]
  end

  def root_named(name)
    config[:roots].detect {|root| root[:name] == name}
  end

  def storage_path
    config[:storage]
  end

end