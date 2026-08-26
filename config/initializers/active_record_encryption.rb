# frozen_string_literal: true

require Rails.root.join("lib/shelfsense/test_secrets")

Rails.application.configure do
  test_keys = !Rails.env.production?
  primary = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].presence
  deterministic = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"].presence
  salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"].presence
  hmac = ENV["GIFT_CARD_NUMBER_HMAC_KEY"].presence

  if test_keys
    primary ||= Shelfsense::TestSecrets::ENCRYPTION_PRIMARY_KEY
    deterministic ||= Shelfsense::TestSecrets::ENCRYPTION_DETERMINISTIC_KEY
    salt ||= Shelfsense::TestSecrets::ENCRYPTION_KEY_DERIVATION_SALT
    hmac ||= Shelfsense::TestSecrets::GIFT_CARD_NUMBER_HMAC_KEY
  elsif [ primary, deterministic, salt, hmac ].any?(&:blank?)
    raise "Active Record Encryption keys and GIFT_CARD_NUMBER_HMAC_KEY must be set in production"
  end

  config.active_record.encryption.primary_key = primary
  config.active_record.encryption.deterministic_key = deterministic
  config.active_record.encryption.key_derivation_salt = salt
  config.x.gift_card_number_hmac_key = hmac
end
