class ManifestCreation < ActiveRecord::Base

  belongs_to :request

  def self.create_for(request)
    Delayed::Job.enqueue(ManifestCreation.create!(request: request), priority: 50)
  end

  def perform

  end

end