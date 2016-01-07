And(/^delayed jobs are run$/) do
  Delayed::Worker.new.work_off
end

Then(/^a manifest should have been generated$/) do
  expect(@request.has_manifest?).to be_truthy
end

And(/^a completion message should have been sent$/) do
  AmqpConnector.instance.with_parsed_message('downloader_to_client_test') do |message|
    expect(message['action']).to eql('request_received')
    expect(message['status']).to eql('ok')
    expect(message['client_id']).to eql('client_id')
    expect(message['id']).to eql(@request.downloader_id)
    expect(message['download_url']).to eql(@request.download_url)
    expect(message['status_url']).to eql(@request.status_url)
  end
end