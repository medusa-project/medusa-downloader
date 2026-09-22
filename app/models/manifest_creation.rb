class ManifestCreation < ActiveRecord::Base

  belongs_to :request

  VALID_QUEUES = %w(amqp sqs).freeze

  validates :queue, inclusion: { in: VALID_QUEUES }

  def self.create_for(request, queue = 'amqp')
    Delayed::Job.enqueue(ManifestCreation.create!(request: request, queue: queue), priority: 50)
  end

  def perform
    self.request.generate_manifest_and_links
    send_completion_notification
  rescue MedusaStorage::InvalidKeyError => e
    send_error_notification(e)
    request.set_status_for_missing_or_invalid_targets
  end

  private

  def send_completion_notification
    if queue == 'sqs'
      SqsRequestBridge.send_request_completed(request)
    else
      AmqpRequestBridge.send_request_completed(request)
    end
  end

  def send_error_notification(error)
    if queue == 'sqs'
      SqsRequestBridge.send_invalid_key_error(error, request)
    else
      AmqpRequestBridge.send_invalid_key_error(error, request)
    end
  end

end