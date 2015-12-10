Given(/^a valid AMQP request is received$/) do
  pending # express the regexp above with the code you wish you had
end

Given(/^an unparseable AMQP request is received$/) do
  Request.from_message('invalid_json')
end

Given(/^an invalid but parseable AMQP request is received$/) do
  pending # express the regexp above with the code you wish you had
end

Then(/^an error message should be sent to the return queue$/) do
  pending # express the regexp above with the code you wish you had
end

And(/^an acknowlegement message should be sent to the return queue$/) do
  pending # express the regexp above with the code you wish you had
end

And(/^a delayed job should be created to process the request$/) do
  pending # express the regexp above with the code you wish you had
end

Then(/^a request should exist with status 'pending'$/) do
  pending # express the regexp above with the code you wish you had
end