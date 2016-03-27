Then(/^the page should not be found$/) do
  expect(page.status_code).to eq(404)
  expect(page.body).to match('Requested archive not found')
end

Then(/^the manifest should not be ready$/) do
  expect(page.status_code).to eq(404)
  expect(page.body).to match('Manifest is not yet ready for this archive')
end

When(/^I visit the status url for a missing archive$/) do
  visit(status_path(id: 'bad_id', root: 'test'))
end

When(/^I visit the download url for a missing archive$/) do
  visit(get_path(id: 'bad_id', root: 'test'))
end

When(/^I visit the manifest url for a missing archive$/) do
  visit(manifest_path(id: 'bad_id', root: 'test'))
end

When(/^I visit the download url for a valid request$/) do
  visit(get_path(id: @request.downloader_id, root: 'test'))
end

When(/^I visit the manifest url for a valid request$/) do
  visit(manifest_path(id: @request.downloader_id, root: 'test'))
end

When(/^I visit the status url for a valid request$/) do
  visit(status_path(id: @request.downloader_id, root: 'test'))
end

Then(/^I should see '(.*)'$/) do |text|
  expect(page.body).to match(text)
end

And(/^I should see a download zip link$/) do
  expect(page.body).to match('Get Zip')
end

Then(/^I should get the manifest for a valid request$/) do
  request = Request.find_by(status: 'ready')
  expect(page.body).to eql(File.read(request.manifest_path))
end

Given(/^I authenticate$/) do
  digest_authorize 'user', 'password'
end

Then(/^I should be unauthorized$/) do
  expect(last_response.status).to eql(401)
end