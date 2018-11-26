Feature: Create download request
  In order to make files available
  As a client
  I want to be able to request download of groups of files

  Scenario: Valid request results in request object and delayed job
    Given a valid AMQP request is received
    Then a request should exist with status 'pending'
    And a delayed job should be created to process the request
    And an acknowlegement message should be sent to the return queue

  Scenario: Invalid root but parseable request returns error message
    Given an invalid root but parseable AMQP request is received
    Then an error message should be sent to the return queue

  Scenario: Invalid, unparseable request fails
    Given an unparseable AMQP request is received
    Then an error message should be emailed to the admin

  Scenario: Valid HTTP request results in request object and delayed job
    Given a valid HTTP request is received
    Then a request should exist with status 'ready'
    And a manifest should have been generated
    And an HTTP response should be received indicating success

  Scenario: Invalid, unparseable HTTP request fails
    Given an unparseable HTTP request is received
    Then no request should have been generated
    And an HTTP response should be received indicating an unparseable request

  Scenario: Invalid root but parseable HTTP request fails
    Given an invalid root but parseable HTTP request is received
    Then no request should have been generated
    And an HTTP response should be received indicating an invalid root

  Scenario: Missing files HTTP request fails
    Given a missing files but parseable HTTP request is received
    Then no request should have been generated
    And an HTTP response should be received indicating missing files

