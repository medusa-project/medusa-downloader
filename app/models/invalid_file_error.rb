class InvalidFileError < RuntimeError

  attr_accessor :root, :relative_path

  def new(root, relative_path)
    self.root = root
    self.relative_path = relative_path
  end

end