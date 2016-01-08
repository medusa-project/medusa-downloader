Feature: Create download request
  In order to make files available
  As a client
  I want to be able to request download of groups of files

  Scenario: Valid request results in request object and delayed job
    Given a valid AMQP request is received
    Then a request should exist with status 'pending'
    And a delayed job should be created to process the request
    And an acknowlegement message should be sent to the return queue

  Scenario: Invalid but parseable request returns error message
    Given an invalid root but parseable AMQP request is received
    Then an error message should be sent to the return queue

  Scenario: Invalid, unparseable request fails
    Given an unparseable AMQP request is received
    Then an error message should be emailed to the admin