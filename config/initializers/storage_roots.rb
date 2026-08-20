if Rails.env.test?
  storage_roots_path = File.join(Rails.root, 'config', 'storage_roots_test.yml')
else
    storage_roots_path = File.join(Rails.root, 'config', 'storage_roots.yml')
end
Rails.logger.warn "Loading storage roots from #{storage_roots_path}"
storage_roots_settings = YAML.load(ERB.new(File.read(storage_roots_path)).result, aliases: true)[Rails.env]
puts storage_roots_settings[:roots]
MedusaDownloader::Application.storage_roots = MedusaStorage::RootSet.new(storage_roots_settings[:roots])