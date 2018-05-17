class ManifestGenerator::Base

  attr_accessor :storage_root, :request,
  delegate :storage_path, :manifest_path, :targets, to: :request

  def initialize(args = {})
    self.storage_root = args[:storage_root]
    self.request = args[:request]
  end

  def generate_manifest_and_links
    raise "Subclass responsibility"
  end

  def data_path
    File.join(storage_path, 'data')
  end

  def literal_path
    File.join(storage_path, 'literal')
  end

end