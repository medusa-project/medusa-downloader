require 'securerandom'
require 'fileutils'

class ManifestGenerator::Filesystem < ManifestGenerator::Base

  attr_accessor :file_list

  def generate_manifest_and_links
    FileUtils.mkdir_p(File.dirname(manifest_path))
    FileUtils.mkdir_p(data_path)
    generate_file_list
    self.total_size = 0
    File.open(manifest_path, 'wb') do |f|
      self.file_list.each.with_index do |spec, i|
        path, zip_path, size = spec
        self.total_size += size
        symlink_path = File.join(data_path, i.to_s)
        FileUtils.symlink(path, symlink_path)
        final_path = "#{zip_name}/#{zip_path}".gsub(/\/+/, '/')
        f.write "- #{size} /internal#{relative_path_to(symlink_path)} #{final_path}\r\n"
      end
    end
  end

  #create from the targets a list of files to be included and also their destinations in the zip file and sizes
  #throw an error if a file/directory does not exist, if it is outside of the root, if the target type is invalid,
  #etc.
  def generate_file_list
    self.file_list = Array.new
    targets.each do |target|
      add_target(target)
    end
  end

  def add_target(target)
    case target['type']
    when 'file'
      add_file(target)
    when 'directory'
      add_directory(target)
    when 'literal'
      add_literal(target)
    else
      raise InvalidTargetTypeError.new(target)
    end
  end

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

  def add_literal(target)
    FileUtils.mkdir_p(literal_path)
    file = new_literal_file
    File.open(file, 'w') do |f|
      f.write(target['content'])
    end
    path = target['zip_path'] || ''
    name = target['name'] || (raise RuntimeError "Name must be provided for literal content.")
    zip_file_path = File.join(path, name)
    self.file_list << [file, zip_file_path, File.size(file)]
  end

  def new_literal_file
    name = File.join(literal_path, SecureRandom.hex(6))
    File.exist?(name) ? literal_file_name : name
  end


end