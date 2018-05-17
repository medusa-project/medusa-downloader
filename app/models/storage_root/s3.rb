class StorageRoot::S3 < StorageRoot
  attr_accessor :bucket, :prefix, :aws_access_key, :aws_secret_access_key

  def initialize(args = {})
    super(args)
    self.bucket = args[:bucket]
    self.prefix = args[:prefix] || ''
    self.aws_access_key = args[:aws_access_key]
    self.aws_secret_access_key = args[:aws_secret_access_key]
  end

  def manifest_generator_class
    ManifestGenerator::S3
  end

end