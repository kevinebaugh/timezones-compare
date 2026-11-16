# Frecency: each visit adds 1, and older visits fade with a one-week half-life.
class BoardVisit < ApplicationRecord
  HALF_LIFE = 7.days

  belongs_to :user

  def self.record!(user, key, at: Time.current)
    visit = find_or_initialize_by(user:, board_key: key)
    visit.update!(score: visit.decayed_score(at) + 1, visited_at: at)
  end

  def decayed_score(at = Time.current)
    return 0.0 if visited_at.nil?
    score * 0.5**((at - visited_at) / HALF_LIFE)
  end
end
