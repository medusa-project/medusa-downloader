class StorageRoot::Filesystem < StorageRoot

  attr_accessor :path, :pathname, :real_path

  def initialize(args = {})
    super(args)
    self.path = args[:path]
    self.pathname = Pathname.new(self.path)
    self.real_path = self.pathname.realpath.to_s
  end

  #We check to make sure that the content requested really lies beneath this root;
  #however, we return the path for linking using the given path so that it remains
  #useable if any symlinks along self.pathname are changed.
  def path_to(relative_path)
    Pathname.new(File.join(self.pathname.to_s, relative_path)).tap do |file_pathname|
      absolute_path = file_pathname.realpath.to_s
      raise InvalidFileError.new(name, relative_path) unless absolute_path.match(/^#{self.real_path}\//)
    end
  rescue Errno::ENOENT
    raise InvalidFileError.new(name, relative_path)
  end

  def manifest_generator_class
    ManifestGenerator::Filesystem
  end

end