class StorageRoot::S3 < StorageRoot
  attr_accessor :bucket, :region, :prefix, :aws_access_key_id, :aws_secret_access_key

  def initialize(args = {})
    super(args)
    self.bucket = args[:bucket]
    self.region = args[:region]
    self.prefix = args[:prefix] || ''
    self.aws_access_key_id = args[:aws_access_key_id]
    self.aws_secret_access_key = args[:aws_secret_access_key]
  end

  def manifest_generator_class
    ManifestGenerator::S3
  end

  def s3_client
    Aws::S3::Client.new(region: region, credentials: s3_credentials)
  end

  def s3_credentials
    Aws::Credentials.new(aws_access_key_id, aws_secret_access_key)
  end

end