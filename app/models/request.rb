require 'fileutils'
require 'open3'
class Request < ActiveRecord::Base

  attr_accessor :storage_root

  has_one :manifest_creation, dependent: :destroy

  STATUSES = %w(pending creating_manifest ready missing_or_invalid_targets)

  validates :status, inclusion: STATUSES, allow_blank: false

  after_destroy :delete_manifest_and_links

  def download_url
    if ensure_storage_root.is_a?(MedusaStorage::Root::Filesystem) && (manifest_line_count > 25000)
      clojure_download_url
    else
      nginx_download_url
    end
  end

  def nginx_download_url
    "#{DOWNLOADER_CONFIG[:nginx_url]}/downloads/#{root}/#{downloader_id}/get"
  end

  def clojure_download_url
    "#{DOWNLOADER_CONFIG[:nginx_url]}/downloads/#{root}/#{downloader_id}/download"
  end

  def status_url
    "#{DOWNLOADER_CONFIG[:nginx_url]}/downloads/#{root}/#{downloader_id}/status"
  end

  def manifest_url
    "#{DOWNLOADER_CONFIG[:nginx_url]}/downloads/#{root}/#{downloader_id}/manifest"
  end

  def has_manifest?
    if manifest_root.is_a?(MedusaStorage::Root::S3)
      manifest_root.exist?(manifest_path)
    else
      File.exist?(manifest_path)
    end
  end

  def manifest_content
    if manifest_root.is_a?(MedusaStorage::Root::S3)
      manifest_root.s3_object(manifest_path).get.body.read
    else
      File.read(manifest_path)
    end
  end

  def manifest_content_scrubbed
    if manifest_root.is_a?(MedusaStorage::Root::S3)
      # Remove the presigned URL query string to prevent display of raw URL
      manifest_content.gsub(/^- (\d+) \S+ ([^\r\n]+)/m, '- \1 \2')
    else
      manifest_content
    end
  end

  def storage_path
    if manifest_root.is_a?(MedusaStorage::Root::S3)
      relative_storage_path
    else
      File.join(manifest_root.path, relative_storage_path)
    end
  end

  def relative_storage_path
    prefix_dirs = downloader_id.first(6).chars.in_groups_of(2).collect(&:join)
    File.join(*prefix_dirs, downloader_id)
  end

  def manifest_path
    File.join(storage_path, 'manifest.txt')
  end

  def manifest_line_count
    output, status = Open3.capture2('wc', '-l', manifest_path)
    output.strip.split(' ').first.to_i
  end

  def delete_manifest_and_links
    FileUtils.rm_rf(storage_path) if storage_path && Dir.exist?(storage_path)
    if manifest_root.is_a?(MedusaStorage::Root::S3)
      manifest_root.s3_bucket.objects(prefix: relative_storage_path).batch_delete!
    end
  end

  def generate_manifest_and_links
    self.status = 'creating_manifest'
    self.save!
    manifest_generator = get_manifest_generator
    manifest_generator.generate_manifest_and_links
    self.total_size = manifest_generator.total_size
    self.status = 'ready'
    self.save!
  end

  def set_status_for_missing_or_invalid_targets
    File.delete(manifest_path) if File.exist?(manifest_path)
    self.status = 'missing_or_invalid_targets'
    self.save!
  end

  STATUSES.each do |status|
    define_method :"#{status}?" do
      self.status == status
    end
  end

  def ensure_storage_root
    self.storage_root ||= MedusaDownloader::Application.storage_roots.at(self.root)
  end

  def manifest_root
    @manifest_root ||= MedusaDownloader::Application.storage_roots.at('manifest')
  end

  def manifest_generator_class
    case ensure_storage_root
    when MedusaStorage::Root::Filesystem
      ManifestGenerator::Filesystem
    when MedusaStorage::Root::S3
      ManifestGenerator::S3
    else
      raise "No ManifestGenerator for provided storage root type"
    end
  end

  def get_manifest_generator
    manifest_generator_class.new(request: self, storage_root: ensure_storage_root)
  end

end
