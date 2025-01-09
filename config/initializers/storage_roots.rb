puts Settings.roots
MedusaDownloader::Application.storage_roots = MedusaStorage::RootSet.new(Settings.roots)