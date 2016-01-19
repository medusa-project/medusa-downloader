require 'securerandom'
require 'fileutils'
class Request < ActiveRecord::Base

  attr_accessor :file_list, :storage_root

  has_one :manifest_creation, dependent: :destroy

  STATUSES = %w(pending creating_manifest ready missing_or_invalid_targets)

  validates :status, inclusion: STATUSES, allow_blank: false

  after_destroy :delete_manifest_and_links

  def download_url
    "#{Config.nginx_url}/downloads/#{downloader_id}/get"
  end

  def status_url
    "#{Config.nginx_url}/downloads/#{downloader_id}/status"
  end

  def manifest_url
    "#{Config.nginx_url}/downloads/#{downloader_id}/manifest"
  end

  def has_manifest?
    File.exist?(manifest_path)
  end

  def storage_path
    File.join(Config.instance.storage_path, self.downloader_id)
  end

  def manifest_path
    File.join(storage_path, 'manifest.txt')
  end

  def data_path
    File.join(storage_path, 'data')
  end

  def delete_manifest_and_links
    FileUtils.rm_rf(storage_path) if Dir.exist?(storage_path)
  end

  def generate_manifest_and_links
    self.status = 'creating_manifest'
    FileUtils.mkdir_p(File.dirname(manifest_path))
    FileUtils.mkdir_p(data_path)
    generate_file_list
    File.open(manifest_path, 'wb') do |f|
      self.file_list.each.with_index do |spec, i|
        path, zip_path, size = spec
        symlink_path = File.join(data_path, i.to_s)
        FileUtils.symlink(path, symlink_path)
        f.write "- #{size} /internal#{relative_path_to(symlink_path)} #{zip_name}/#{zip_path}\r\n"
      end
    end
    self.status = 'ready'
    self.save!
  rescue InvalidFileError => e
    AmqpRequestBridge.send_invalid_file_error(e, self)
    File.delete(manifest_path) if File.exist?(manifest_path)
    self.status = 'missing_or_invalid_targets'
    self.save!
  end

#create from the targets a list of files to be included and also their destinations in the zip file and sizes
#throw an error if a file/directory does not exist, if it is outside of the root, if the target type is invalid,
#etc.
  def generate_file_list
    self.storage_root = StorageRoot.find(self.root)
    self.file_list = Array.new
    self.targets.each do |target|
      add_target(target)
    end
  end

  def add_target(target)
    case target['type']
      when 'file'
        add_file(target)
      when 'directory'
        add_directory(target)
      else
        raise InvalidTargetTypeError.new(target)
    end
  end

  def add_file(target)
    file_path = self.storage_root.path_to(target['path'])
    raise InvalidFileError(self.root, target['path']) unless File.file?(file_path)
    zip_file_path = target[:zip_path] || File.basename(file_path)
    size = File.size(file_path)
    self.file_list << [file_path, zip_file_path, size]
  end

  def add_directory(target)
    directory_path = self.storage_root.path_to(target['path'])
    raise InvalidFileError(self.root, target['path']) unless Dir.exist?(directory_path)
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

  def relative_path_to(absolute_path)
    absolute_path.sub(/^#{Config.instance.storage_path}/, '')
  end

  STATUSES.each do |status|
    define_method :"#{status}?" do
      self.status == status
    end
  end

end
