# Encryption keys for Slack tokens. Set the ACTIVE_RECORD_ENCRYPTION_* env vars
# to manage them explicitly; otherwise they are derived from secret_key_base so
# a self-hosted install only needs one secret.
Rails.application.config.after_initialize do
  generator = Rails.application.key_generator
  derive = ->(purpose) { generator.generate_key("active_record_encryption/#{purpose}", 32).unpack1("H*") }

  ActiveRecord::Encryption.configure(
    primary_key: ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY") { derive.("primary_key") },
    deterministic_key: ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY") { derive.("deterministic_key") },
    key_derivation_salt: ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT") { derive.("key_derivation_salt") }
  )
end
