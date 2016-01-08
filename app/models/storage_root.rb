require 'pathname'
class StorageRoot

  attr_accessor :name, :path, :pathname, :real_path

  def self.find(name)
    root = Config.root_named(name)
    raise InvalidStorageRootError.new(root) unless root
    return new(root)
  end

  def initialize(args = {})
    self.name = args[:name]
    self.path = args[:path]
    self.pathname = Pathname.new(self.path)
    self.real_path = self.pathname.realpath.to_s
  end

  def path_to(relative_path)
    file_pathname = Pathname.new(File.join(self.pathname.to_s, relative_path))
    file_pathname.realpath.to_s.tap do |absolute_path|
      raise InvalidFileError(name, relative_path) unless absolute_path.match(/^#{self.real_path}/)
    end
  end

end