require 'pathname'
class StorageRoot

  attr_accessor :name, :path, :pathname, :real_path

  def initialize(args = {})
    self.name = args[:name]
  end

  def manifest_generator(request)
    manifest_generator_class.new(storage_root: self, request: request)
  end

  def manifest_generator_class
    raise "Subclass responsibility"
  end

end