# Sunrise, sunset, and civil twilight for a time zone on a given local date,
# using the zone's tzdb reference coordinates (e.g. Europe/London -> London).
# It's an approximation for a whole zone, which is exactly what a row in the
# grid represents. Accurate to a couple of minutes for the reference city.
#
#   Daylight.for("Europe/London", Date.new(2026, 6, 21)).sunrise # => UTC Time
class Daylight
  J2000 = 2_451_545.0
  UNIX_EPOCH_JD = 2_440_587.5
  SUNRISE_ALTITUDE = -0.833 # refraction + solar disc
  CIVIL_ALTITUDE = -6.0

  # polar / civil_polar are :day or :night when the sun never crosses the
  # sunrise / civil-twilight altitude that day.
  Day = Data.define(:dawn, :sunrise, :sunset, :dusk, :polar, :civil_polar) do
    # :night, :twilight, or :day at the given instant.
    def phase_at(time)
      return :day if polar == :day || (sunrise && time >= sunrise && time < sunset)
      return :twilight if civil_polar == :day || (dawn && time >= dawn && time < dusk)
      :night
    end
  end

  class << self
    def for(tz, date)
      lat, lon = coordinates(tz)
      calculate(lat, lon, date)
    end

    def coordinates(tz)
      zone = TZInfo::Timezone.get(tz)
      table[zone.identifier] || table[zone.canonical_identifier] || estimated_coordinates(zone)
    rescue TZInfo::InvalidTimezoneIdentifier
      [ 0.0, 0.0 ]
    end

    def calculate(lat, lon, date)
      n = date.jd - J2000
      j_star = n - lon / 360.0
      mean_anomaly = (357.5291 + 0.98560028 * j_star) % 360
      m = rad(mean_anomaly)
      center = 1.9148 * Math.sin(m) + 0.0200 * Math.sin(2 * m) + 0.0003 * Math.sin(3 * m)
      ecliptic_longitude = rad((mean_anomaly + center + 180 + 102.9372) % 360)
      transit = J2000 + j_star + 0.0053 * Math.sin(m) - 0.0069 * Math.sin(2 * ecliptic_longitude)
      declination = Math.asin(Math.sin(ecliptic_longitude) * Math.sin(rad(23.4397)))

      sunrise, sunset, polar = crossing(transit, lat, declination, SUNRISE_ALTITUDE)
      dawn, dusk, civil_polar = crossing(transit, lat, declination, CIVIL_ALTITUDE)
      Day.new(dawn:, sunrise:, sunset:, dusk:, polar:, civil_polar:)
    end

    private
      def crossing(transit, lat, declination, altitude)
        phi = rad(lat)
        cos_hour_angle = (Math.sin(rad(altitude)) - Math.sin(phi) * Math.sin(declination)) /
                         (Math.cos(phi) * Math.cos(declination))
        return [ nil, nil, :night ] if cos_hour_angle > 1
        return [ nil, nil, :day ] if cos_hour_angle < -1

        half_day = deg(Math.acos(cos_hour_angle)) / 360.0
        [ jd_to_time(transit - half_day), jd_to_time(transit + half_day), nil ]
      end

      def jd_to_time(jd)
        Time.at(((jd - UNIX_EPOCH_JD) * 86_400).round).utc
      end

      def rad(degrees) = degrees * Math::PI / 180
      def deg(radians) = radians * 180 / Math::PI

      # Zones without a country entry (Etc/*, UTC): guess from the UTC offset.
      def estimated_coordinates(zone)
        [ 0.0, zone.base_utc_offset / 3600.0 * 15 ]
      end

      def table
        @table ||= TZInfo::Country.all.each_with_object({}) do |country, map|
          country.zone_info.each do |info|
            map[info.identifier] ||= [ info.latitude.to_f, info.longitude.to_f ]
          end
        end.freeze
      end
  end
end
