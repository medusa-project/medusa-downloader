require 'pathname'
class ManifestGenerator::S3 < ManifestGenerator::Base

  delegate :bucket, :region, to: :storage_root


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

  def write_file_list_and_compute_size
    self.total_size = 0
    File.open(manifest_path, 'wb') do |f|
      self.file_list.each.with_index do |spec, i|
        path, zip_path, size, literal = spec
        self.total_size += size
        final_path = "#{request.zip_name}/#{zip_path}".gsub(/\/+/, '/')
        if literal
          symlink_path = File.join(data_path, i.to_s)
          FileUtils.symlink(path, symlink_path)
          f.write "- #{size} /internal#{relative_path_to(symlink_path)} #{final_path}\r\n"
        else
          f.write "- #{size} #{normalized_path(path)} #{final_path}\r\n"
        end
      end
    end
  end

#convert a url like https://dls-medusa-test.s3.us-east-2.amazonaws.com/nfs_lock_test.sh?params to
# /<bucket>/nfs_lock_test.sh?params
  def normalized_path(path)
    truncated_path = path.gsub(/^(.*?)amazonaws.com\//, '')
    "/#{bucket}/#{truncated_path}"
  end
  
end