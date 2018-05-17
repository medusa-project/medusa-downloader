require 'pathname'
class StorageRoot

  attr_accessor :name, :path, :pathname, :real_path

  def initialize(args = {})
    self.name = args[:name]
  end


end