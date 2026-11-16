class Current < ActiveSupport::CurrentAttributes
  attribute :user
  attribute :accounts # every workspace this browser is signed into
end
