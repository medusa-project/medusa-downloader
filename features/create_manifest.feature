Feature: Create manifest
  As the system
  In order to service requests promptly
  I want to create manifests in the background

  Scenario: Delayed job produces manifest from valid request and notifies client
    Given a valid AMQP request is received
    Then an acknowlegement message should be sent to the return queue
    When delayed jobs are run
    Then a manifest should have been generated
    And a request should exist with status 'ready'
    And a completion message should have been sent

  Scenario: Delayed job fails to produce manifest if files are missing and notifies client
    Given a missing files but parseable AMQP request is received
    And delayed jobs are run
    Then no manifest should have been generated
    And a missing files message should have been sent
    And a request should exist with status 'missing_or_invalid_targets'


