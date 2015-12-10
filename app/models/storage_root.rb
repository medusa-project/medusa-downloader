class StorageRoot

  attr_accessor :name, :path

  def self.find(name)
    root = Config.root_named(name)
    return nil unless root
    return new(root)
  end

  def initialize(args = {})
    self.name = args[:name]
    self.path = args[:path]
  end

end