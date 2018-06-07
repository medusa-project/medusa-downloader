class ManifestCreation < ActiveRecord::Base

  belongs_to :request

  def self.create_for(request)
    Delayed::Job.enqueue(ManifestCreation.create!(request: request), priority: 50)
  end

  def perform
    self.request.generate_manifest_and_links
    AmqpRequestBridge.send_request_completed(request)
  rescue MedusaStorage::InvalidKeyError => e
    AmqpRequestBridge.send_invalid_key_error(e, request)
    request.set_status_for_missing_or_invalid_targets
  end

end