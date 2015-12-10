require 'singleton'

class Config < Object
  include Singleton

  attr_accessor :config

  def initialize
    self.config = YAML.load_file(File.join(Rails.root, 'config', 'medusa_downloader.yml'))[Rails.env].with_indifferent_access
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

end