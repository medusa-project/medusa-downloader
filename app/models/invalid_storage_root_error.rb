class InvalidStorageRootError < RuntimeError
  attr_accessor :root

  def new(root)
    self.root = root
  end

end