require 'securerandom'
require 'fileutils'

class ManifestGenerator::Filesystem < ManifestGenerator::Base

  def add_file(target)
    file_path = storage_root.path_to(target['path'])
    raise InvalidFileError(request.root, target['path']) unless File.file?(file_path)
    path = target['zip_path'] || ''
    name = target['name'] || File.basename(file_path)
    zip_file_path = File.join(path, name)
    size = File.size(file_path)
    self.file_list << [file_path, zip_file_path, size]
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
        self.file_list << [descendant.to_s, zip_file_path, size]
      else
        Find.prune if recurse.blank? and descendant.directory?
      end
    end
  end


end