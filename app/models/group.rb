# A Slack user group (e.g. @mobile-team), mirrored on every roster sync.
class Group < ApplicationRecord
  belongs_to :workspace
  has_many :group_memberships, dependent: :delete_all
  has_many :members, through: :group_memberships

  validates :slack_group_id, :name, :handle, presence: true

  scope :by_name, -> { order(Arel.sql("LOWER(name)")) }
end
