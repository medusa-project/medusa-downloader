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
    self.file_list << [file_url, zip_file_path, size, false]
  rescue Aws::S3::Errors::NotFound
    raise InvalidFileError(request.root, target['path'])
  end

  def add_directory(target)
    #TODO the main problem here is to get all of the keys under the target. In the worst case we can set this up as a
    # call out to rclone, but hopefully the AWS SDK  provides a way to do it directly. It looks like list_objects_v2
    # with a set prefix ang pagination will work for
    # recursive listing. It may be harder to do it for non recursive grabbing.
    # For recursive we do client.list_objects_v2(bucket: bucket, prefix: prefix). This will have keys in contents.keys. Then as long
    # as we have a next_continuation_token, keep redoing the request.
    # For non-recursive we might just have to get all the keys and filter them - chop off the prefix and get everything that
    # doesn't have a slash.
    # Then we need to add them to the file list in the right way. So there are some details here, but everything should
    # be doable. It may be easier than for the filesystem because we have the complete key already.
    # We may also get keys ending in '/', which we want to reject
    key_prefix = key_for(target['path'])
    key_prefix = key_prefix + '/' unless key_prefix.end_with?('/')
    keys = Array.new
    continuation_token = nil
    #This gets only those in the specified 'directory' unless recursion is specified
    delimiter = (target['recursive'] == true) ? nil : '/'
    loop do
      results = s3_client.list_objects_v2(bucket: bucket, prefix: key_prefix, continuation_token: continuation_token, delimiter: delimiter)
      keys += results.contents.collect(&:key).reject {|key| key.end_with?('/')}
      continuation_token = results.next_continuation_token
      break if continuation_token.nil?
    end
    #add to the file list for each key, similarly to add_file but preserving the right path info and such
    #once again, we'll need to get the size and presigned url. May admit some refactoring after.
  end

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