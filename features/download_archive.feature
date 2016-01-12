Feature: Download archive
  In order to get my content
  As a user
  I want to be able to visit a url and get a zip archive or status report

  Scenario: Download an archive given that a request and manifest have been produced
    When PENDING

  Scenario: Attempt to download an archive that does not exist
    When I visit the download url for a missing archive
    Then the page should not be found

  Scenario: Get a status report for an existing request
    When PENDING

  Scenario: Get a status report for an archive that does not exist
    When I visit the status url for a missing archive
    Then the page should not be found

  Scenario: Get a manifest for an existing request
    When PENDING

  Scenario: Get a status report for an archive that does not exist
    When I visit the manifest url for a missing archive
    Then the page should not be found