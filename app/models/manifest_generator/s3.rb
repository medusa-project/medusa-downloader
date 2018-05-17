class ManifestGenerator::S3 < ManifestGenerator::Base

  delegate :bucket, :region, :prefix, to: :storage_root

  def s3_client
    @s3_client ||= storage_root.s3_client
  end

  def presigner
    @presigner ||= Aws::S3::Presigner.new(client: s3_client)
  end

  def add_file(target)
    path = target['zip_path'] || ''
    name = target['name'] || File.basename(target['path'])
    zip_file_path = File.join(path, name)
    key = key_for(target['path'])
    info = s3_client.head_object(bucket: bucket, key: key)
    size = info.content_length
    file_url = presigner.presigned_url(:get_object, bucket: bucket, key: key, expires_in: 7.days.to_i)
    Rails.logger.error "Generated url #{file_url} for #{bucket}/#{key}"
    self.file_list << [file_url, zip_file_path, size, false]
  rescue Aws::S3::Errors::NotFound
    raise InvalidFileError(request.root, target['path'])
  end

  def add_directory(target)
    raise "Not yet implemented"
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

end