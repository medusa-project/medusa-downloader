require 'pathname'
class ManifestGenerator::S3 < ManifestGenerator::Base

  delegate :bucket, :region, to: :storage_root


  def generate_manifest_and_links
    generate_file_list
    write_file_list_and_compute_size
  end

  def add_file(target)
    path = target['zip_path'] || ''
    name = target['name'] || File.basename(target['path'])
    zip_file_path = File.join(path, name)
    key = target['path']
    size = storage_root.size(key)
    file_url = storage_root.presigned_get_url(key)
    self.file_list << [file_url, zip_file_path, size, false]
  rescue Aws::S3::Errors::NotFound
    raise MedusaStorage::InvalidKeyError.new(request.root, target['path'])
  end

  def add_directory(target)
    directory_key = storage_root.ensure_directory_key(target['path'])
    directory_path = Pathname.new(directory_key)
    keys = if target['recursive'] == true
             storage_root.subtree_keys(directory_key)
           else
             storage_root.file_keys(directory_key)
           end
    zip_path = target['zip_path'] || target['path']
    Parallel.each(keys, in_threads: 10) do |key|
      begin
        relative_path = Pathname.new(key).relative_path_from(directory_path).to_s
        zip_file_path = File.join(zip_path, relative_path)
        size = storage_root.size(key)
        file_url = storage_root.presigned_get_url(key)
        self.file_list << [file_url, zip_file_path, size, false]
      rescue Aws::S3::Errors::NotFound
        raise MedusaStorage::InvalidKeyError.new(request.root, key)
      end
    end
  end

  def add_literal(target)
    name = target['name'] || raise(RuntimeError, 'Name must be provided for literal content.')
    zip_path = target['zip_path'] || ''
    zip_file_path = File.join(zip_path, name)
    content = target['content']
    size = content.bytesize
    key = new_literal_file
    downloader_root.s3_object(key).put(body: content)
    file_url = downloader_root.presigned_get_url(key)
    self.file_list << [file_url, zip_file_path, size, false]
  end

    def new_literal_file
    name = File.join(literal_path, SecureRandom.hex(6))
    downloader_root.exist?(name) ? literal_file_name : name
  end

  def write_file_list_and_compute_size
    self.total_size = 0
    content = StringIO.new
    self.file_list.each do |spec|
      path, zip_path, size, _literal = spec
      self.total_size += size
      final_path = "#{request.zip_name}/#{zip_path}".gsub(/\/+/, '/')
      content.write("- #{size} #{normalized_path(path)} #{final_path}\r\n")
    end
    downloader_root.s3_object(manifest_path).put(body: content.string)
  end

  def downloader_root
    @downloader_root ||= MedusaDownloader::Application.storage_roots.at('downloader')
  end

#convert a url like https://dls-medusa-test.s3.us-east-2.amazonaws.com/nfs_lock_test.sh?params to
# /<bucket>/nfs_lock_test.sh?params
  def normalized_path(path)
    uri = URI.parse(path)
    host_bucket = uri.host.split('.').first
    "/#{host_bucket}#{uri.path}?#{uri.query}"
  end
  
end