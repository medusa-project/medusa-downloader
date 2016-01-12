Feature: Download archive
  In order to get my content
  As a user
  I want to be able to visit a url and get a zip archive or status report

  Scenario: Download an archive given that a request and manifest have been produced
    When PENDING

  Scenario: Attempt to download an archive that does not exist
    When I visit the download url for a missing archive
    Then the page should not be found

  Scenario: Attempt to download an archive that exists but is not yet ready
    Given a valid AMQP request is received
    When I visit the download url for a valid request
    Then the manifest should not be ready

  Scenario: Get a status report for an existing request
    Given a valid AMQP request is received
    When I visit the status url for a valid request
    Then I should see 'pending'

  Scenario: Get a status report for a ready request
    Given a valid AMQP request is received
    And delayed jobs are run
    When I visit the status url for a valid request
    Then I should see 'ready'
    And I should see a download zip link

  Scenario: Get a status report for an archive that does not exist
    When I visit the status url for a missing archive
    Then the page should not be found

  Scenario: Get a manifest for an existing request
    Given a valid AMQP request is received
    And delayed jobs are run
    When I visit the manifest url for a valid request
    Then I should get the manifest for a valid request

  Scenario: Get a manifest for an archive that does not exist
    When I visit the manifest url for a missing archive
    Then the page should not be found

  Scenario: Attempt to get a manifiest for an archive that exists but is not yet ready
    Given a valid AMQP request is received
    When I visit the manifest url for a valid request
    Then the manifest should not be ready