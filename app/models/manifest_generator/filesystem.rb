require 'securerandom'
require 'fileutils'

class ManifestGenerator::Filesystem < ManifestGenerator::Base

  def add_file(target)
    file_url = storage_root.path_to(target['path'])
    raise InvalidFileError(request.root, target['path']) unless File.file?(file_url)
    path = target['zip_path'] || ''
    name = target['name'] || File.basename(file_url)
    zip_file_path = File.join(path, name)
    size = File.size(file_url)
    self.file_list << [file_url, zip_file_path, size, true]
  end

  def add_directory(target)
    directory_path = storage_root.path_to(target['path'])
    raise InvalidFileError(request.root, target['path']) unless Dir.exist?(directory_path)
    zip_path = target['zip_path'] || target['path']
    recurse = target['recursive'] == true
    dir = Pathname.new(directory_path)
    dir.find.each do |descendant|
      next if descendant == dir
      if descendant.file?
        zip_file_path = File.join(zip_path, descendant.to_s.sub(/^#{dir.to_s}\//, ''))
        size = descendant.size
        self.file_list << [descendant.to_s, zip_file_path, size, true]
      else
        Find.prune if recurse.blank? and descendant.directory?
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
        symlink_path = File.join(data_path, i.to_s)
        FileUtils.symlink(path, symlink_path)
        f.write "- #{size} /internal#{relative_path_to(symlink_path)} #{final_path}\r\n"
      end
    end
  end

end