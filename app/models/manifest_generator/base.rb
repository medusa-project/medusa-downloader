class ManifestGenerator::Base

  attr_accessor :storage_root, :request, :file_list, :total_size
  delegate :storage_path, :manifest_path, :targets, to: :request

  def initialize(args = {})
    self.storage_root = args[:storage_root]
    self.request = args[:request]
  end

  def generate_manifest_and_links
    if manifest_root.is_a?(MedusaStorage::Root::Filesystem)
      FileUtils.mkdir_p(File.dirname(manifest_path))
      FileUtils.mkdir_p(data_path)
    end
    generate_file_list
    write_file_list_and_compute_size
  end

  #create from the targets a list of files to be included and also their destinations in the zip file and sizes
  #throw an error if a file/directory does not exist, if it is outside of the root, if the target type is invalid,
  #etc.
  def generate_file_list
    self.file_list = Concurrent::Array.new
    targets.each do |target|
      add_target(target)
    end
  end

  def data_path
    File.join(storage_path, 'data')
  end

  def literal_path
    File.join(storage_path, 'literal')
  end

  def relative_path_to(absolute_path)
    absolute_path.sub(/^#{manifest_root.path}/, '')
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

  def add_literal(target)
    name = target['name'] || raise(RuntimeError, 'Name must be provided for literal content.')
    zip_path = target['zip_path'] || ''
    zip_file_path = File.join(zip_path, name)
    content = target['content']
    size = content.bytesize
    file_name = new_literal_file
    if manifest_root.is_a?(MedusaStorage::Root::S3)
      manifest_root.s3_object(file_name).put(body: content)
      file_url = manifest_root.presigned_get_url(file_name)
      self.file_list << [file_url, zip_file_path, size, true]
    else
      FileUtils.mkdir_p(literal_path)
      File.open(file_name, 'w') do |f|
        f.write(target['content'])
      end
      self.file_list << [file_name, zip_file_path, File.size(file_name), true]
    end
  end

  def new_literal_file
    name = File.join(literal_path, SecureRandom.hex(6))
    manifest_root.exist?(name) ? new_literal_file : name
  end

  def manifest_root
    @manifest_root ||= MedusaDownloader::Application.storage_roots.at('manifest')
  end


end