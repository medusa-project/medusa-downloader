Given(/^a valid AMQP request is received$/) do
  @request = Request.from_message(valid_amqp_request)
end

Given(/^an unparseable AMQP request is received$/) do
  Request.from_message('invalid_json')
end

Given(/^an invalid but parseable AMQP request is received$/) do
  Request.from_message(invalid_amqp_request)
end

Then(/^an error message should be sent to the return queue$/) do
  AmqpConnector.instance.with_parsed_message('downloader_to_client_test') do |message|
    expect(message['action']).to eql('request_received')
    expect(message['status']).to eql('error')
    expect(message['client_id']).to eql('client_id')
    expect(message['error']).to match(/Invalid root/)
  end
end

And(/^an acknowlegement message should be sent to the return queue$/) do
  AmqpConnector.instance.with_parsed_message('downloader_to_client_test') do |message|
    expect(message['action']).to eql('request_received')
    expect(message['client_id']).to eql(@request.client_id)
    expect(message['id']).to eql(@request.downloader_id)
    expect(message['status']).to eql('ok')
    expect(message['download_url']).to be_present
    expect(message['status_url']).to be_present
  end
end

And(/^a delayed job should be created to process the request$/) do
  expect(@request.manifest_creation).to be_present
  expect(Delayed::Job.count).to eq(1)
end

Then(/^a request should exist with status 'pending'$/) do
  expect(Request.find_by(status: 'pending')).to be_present
end

def valid_amqp_request
  {action: :export,
   client_id: :client_id,
   root: :test,
   return_queue: :downloader_to_client_test,
   targets: [
       {type: :file, path: 'cat.txt'},
       {type: :directory, path: 'child/grandchild', recursive: false}
   ]}.to_json.to_s
end

def invalid_amqp_request
  {action: :export,
   client_id: :client_id,
   root: :unknown_root,
   return_queue: :downloader_to_client_test,
   targets: [
       {type: :file, path: 'cat.txt'},
       {type: :directory, path: 'child/grandchild', recursive: false}
   ]}.to_json.to_s
end