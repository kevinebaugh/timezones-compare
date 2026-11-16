module GridParams
  extend ActiveSupport::Concern

  MAX_SHARED_ZONES = 24

  private
    def grid_date
      Date.iso8601(params[:date]) if params[:date].present?
    rescue Date::Error
      nil
    end

    # A shared slot's length in minutes (?d=45): quarter hours, up to a day.
    def meeting_minutes
      minutes = params[:d].to_i
      minutes if minutes.positive? && (minutes % 15).zero? && minutes <= 24 * 60
    end

    # A comma-separated list of time zone ids, as shared links carry them:
    # unknown ids dropped, aliases made canonical, at most MAX_SHARED_ZONES.
    def zone_list(value)
      value.to_s.split(",").filter_map { |id| TZInfo::Timezone.get(id).canonical_identifier if TZInfo::Timezone.all_identifiers.include?(id) }
           .uniq.first(MAX_SHARED_ZONES)
    end

    # When a shared link was made (?g= / ?shared_at=), if it's a sensible time.
    def shared_at(value)
      at = Time.at(value.to_i).utc if value.to_s.match?(/\A\d{1,12}\z/)
      at if at&.between?(5.years.ago, 1.day.from_now)
    end

    def grid_tz(fallback)
      tz = params[:tz].presence
      tz && TZInfo::Timezone.all_identifiers.include?(tz) ? tz : fallback
    end
end
