class ManifestCreation < ActiveRecord::Base

  belongs_to :request

  def self.create_for(request)
    Delayed::Job.enqueue(ManifestCreation.create!(request: request), priority: 50)
  end

  def perform
    self.request.generate_manifest_and_links
  rescue InvalidFileError => e
    AmqpRequestBridge.send_invalid_file_error(e, request)
    request.set_status_for_missing_or_invalid_targets
  end

end