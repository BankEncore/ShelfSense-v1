# frozen_string_literal: true

# Documented non-production Active Record Encryption keys and HMAC secret.
# Production must set these via the environment. Do not use these values outside
# local Docker, test, and CI. See docs/development.md.
module Shelfsense
  module TestSecrets
    ENCRYPTION_PRIMARY_KEY = "0000000000000000000000000000000000000000000000000000000000000001"
    ENCRYPTION_DETERMINISTIC_KEY = "0000000000000000000000000000000000000000000000000000000000000002"
    ENCRYPTION_KEY_DERIVATION_SALT = "0000000000000000000000000000000000000000000000000000000000000003"
    GIFT_CARD_NUMBER_HMAC_KEY = "shelfsense-test-gift-card-hmac-key-not-for-production"
  end
end
