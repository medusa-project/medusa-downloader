class StorageRootFinder

  def self.find(name)
    root = Config.root_named(name)
    raise Request::InvalidRoot unless root
    root_class = case root[:type].to_s
                 when 'filesystem', ''
                   StorageRoot::Filesystem
                 when 's3'
                   StorageRoot::S3
                 else
                   raise "Unrecognized storage root type"
                 end
    return root_class.new(root)
  end

end