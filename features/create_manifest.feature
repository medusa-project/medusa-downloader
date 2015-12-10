Feature: Create manifest
  As the system
  In order to service requests promptly
  I want to create manifests in the background

  Scenario: Delayed job produces manifest from valid request and notifies client
    When PENDING

  Scenario: Delayed job fails to produce manifest if files are missing and notifies client
    When PENDING

