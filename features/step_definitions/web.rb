Then(/^the page should not be found$/) do
  expect(page.status_code).to eq(404)
  expect(page.body).to match('Requested archive not found')
end

When(/^I visit the status url for a missing archive$/) do
  visit(status_path(id: 'bad_id'))
end

When(/^I visit the download url for a missing archive$/) do
  visit(get_path(id: 'bad_id'))
end

When(/^I visit the manifest url for a missing archive$/) do
  visit(manifest_path(id: 'bad_id'))
end