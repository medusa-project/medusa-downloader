And(/^delayed jobs are run$/) do
  Delayed::Worker.new.work_off
end

Then(/^a manifest should have been generated$/) do
  expect(@request.has_manifest?).to be_truthy
end

And(/^a completion message should have been sent$/) do
  pending # express the regexp above with the code you wish you had
end