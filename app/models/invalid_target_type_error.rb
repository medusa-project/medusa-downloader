class InvalidTargetTypeError < RuntimeError

  attr_accessor :target

  def initialize(target)
    self.target = target
  end

end