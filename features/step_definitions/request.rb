Given(/^a valid AMQP request is received$/) do
  @request = AmqpRequestBridge.create_request(valid_amqp_request)
end

Given(/^an unparseable AMQP request is received$/) do
  @request = AmqpRequestBridge.create_request('invalid_json')
end

Given(/^an invalid root but parseable AMQP request is received$/) do
  @request = AmqpRequestBridge.create_request(invalid_root_amqp_request)
end

Given(/^a missing files but parseable AMQP request is received$/) do
  @request = AmqpRequestBridge.create_request(missing_files_amqp_request)
end

Then(/^an error message should be sent to the return queue$/) do
  AmqpConnector.instance.with_parsed_message('downloader_to_client_test') do |message|
    expect(message['action']).to eql('request_received')
    expect(message['status']).to eql('error')
    expect(message['client_id']).to eql('client_id')
    expect(message['error']).to match(/Invalid root/)
  end
end

And(/^a missing files message should have been sent$/) do
  step "an acknowlegement message should be sent to the return queue"
  AmqpConnector.instance.with_parsed_message('downloader_to_client_test') do |message|
    expect(message['action']).to eql('error')
    expect(message['id']).to eql(@request.downloader_id)
    expect(message['error']).to match(/Missing or invalid file or directory/)
    expect(message['error']).to match(/missing_file_name/)
  end
end

And(/^an acknowlegement message should be sent to the return queue$/) do
  AmqpConnector.instance.with_parsed_message('downloader_to_client_test') do |message|
    expect(message['action']).to eql('request_received')
    expect(message['client_id']).to eql(@request.client_id)
    expect(message['id']).to eql(@request.downloader_id)
    expect(message['status']).to eql('ok')
    expect(message['download_url']).to eql(@request.download_url)
    expect(message['status_url']).to eql(@request.status_url)
  end
end

And(/^a delayed job should be created to process the request$/) do
  expect(@request.manifest_creation).to be_present
  expect(Delayed::Job.count).to eq(1)
end

Then(/^a request should exist with status '(.*)'$/) do |status|
  expect(Request.find_by(status: status)).to be_present
end

Then(/^no request should have been generated$/) do
  expect(Request.count).to eql(0)
end

Given(/^a valid HTTP request is received$/) do
  header 'Content-Type', 'application/json'
  post create_download_path, valid_request_hash.to_json.to_s
  @request = Request.first
end

And(/^an HTTP response should be received indicating success$/) do
  expect(last_response.status).to eql(201)
  message = JSON.parse(last_response.body)
  expect(message['id']).to eql(@request.downloader_id)
  expect(message['status']).to eql('ok')
  expect(message['download_url']).to eql(@request.download_url)
  expect(message['status_url']).to eql(@request.status_url)
end

Given(/^an unparseable HTTP request is received$/) do
  post create_download_path, 'invalid_json'
end

Then(/^an HTTP response should be received indicating an unparseable request$/) do
  expect(last_response.status).to eql(400)
  message = JSON.parse(last_response.body)
  expect(message['error']).to eql('Unable to parse request body')
end

Given(/^an invalid root but parseable HTTP request is received$/) do
  header 'Content-Type', 'application/json'
  post create_download_path, invalid_root_request_hash.to_json.to_s
end

Then(/^an HTTP response should be received indicating an invalid root$/) do
  expect(last_response.status).to eql(400)
  message = JSON.parse(last_response.body)
  expect(message['error']).to match('Invalid root')
end

Given(/^a missing files but parseable HTTP request is received$/) do
  header 'Content-Type', 'application/json'
  post create_download_path, missing_files_amqp_request
end

And(/^an HTTP response should be received indicating missing files$/) do
  expect(last_response.status).to eql(400)
  message = JSON.parse(last_response.body)
  expect(message['error']).to match('Invalid or missing file')
end

def valid_request_hash
  {action: :export,
   client_id: :client_id,
   root: :test,
   return_queue: :downloader_to_client_test,
   targets: [
       {type: :file, path: 'cat.txt'},
       {type: :directory, path: 'child', recursive: false}
   ]}.clone
end

def invalid_root_request_hash
  valid_request_hash.tap do |h|
    h[:root] = :unknown_root
  end
end

def valid_amqp_request
  valid_request_hash.to_json.to_s
end

def invalid_root_amqp_request
  invalid_root_request_hash.to_json.to_s
end

def missing_files_amqp_request
  h = valid_request_hash
  h[:targets] = [{type: :file, path: :missing_file_name}]
  h.to_json.to_s
end