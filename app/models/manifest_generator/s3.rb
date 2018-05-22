class ManifestGenerator::S3 < ManifestGenerator::Base

  delegate :bucket, :region, :prefix, to: :storage_root


  def add_file(target)
    path = target['zip_path'] || ''
    name = target['name'] || File.basename(target['path'])
    zip_file_path = File.join(path, name)
    key = key_for(target['path'])
    size = storage_root.size(key)
    file_url = storage_root.presigned_get_url(key)
    self.file_list << [file_url, zip_file_path, size, false]
  rescue Aws::S3::Errors::NotFound
    raise InvalidFileError(request.root, target['path'])
  end

  def add_directory(target)
    key = key_for(target['path'])
    keys = if target['recursive'] == true
             storage_root.subtree_keys(key)
           else
             storage_root.file_keys(key)
           end
    zip_path = target['zip_path'] || target['path']
    keys.each do |key|
      begin
        zip_file_path = File.join(zip_path, relative_path(key, target['path']))
        size = storage_root.size(key)
        file_url = storage_root.presigned_get_url(key)
        self.file_list << [file_url, zip_file_path, size, false]
      rescue Aws::S3::Errors::NotFound
        raise InvalidFileError(request.root, key)
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

  def key_for(path)
    if prefix.blank?
      path
    else
      File.join(prefix, path)
    end
  end

#convert a url like https://dls-medusa-test.s3.us-east-2.amazonaws.com/nfs_lock_test.sh?params to
# /<bucket>/nfs_lock_test.sh?params
  def normalized_path(path)
    truncated_path = path.gsub(/^(.*?)amazonaws.com\//, '')
    "/#{bucket}/#{truncated_path}"
  end

  def relative_path(full_key, directory)
    directory = directory + '/' unless directory.end_with?('/')
    prefix_to_remove = key_for(directory)
    full_key.sub(/^#{prefix_to_remove}/, '')
  end

end