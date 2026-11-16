module GridHelper
  PHASE_VARS = { day: [ "var(--day)", "var(--day-ink)" ], twilight: [ "var(--twilight)", "var(--twilight-ink)" ], night: [ "var(--night)", "var(--night-ink)" ] }.freeze

  def clock_preference
    return cookies[:clock] if %w[12 24].include?(cookies[:clock])
    Languages.twelve_hour?(I18n.locale) ? "12" : "24"
  end

  def tz_cell_style(cell)
    a, = PHASE_VARS.fetch(cell.phase_start)
    b, = PHASE_VARS.fetch(cell.phase_end)
    ink = PHASE_VARS.fetch(cell.phase_end == :day || cell.phase_start == :day ? :day : cell.phase_start).last
    "--a:#{a};--b:#{b};--ink-c:#{ink}"
  end

  # A small bell, Slack's own symbol for notifications.
  def notification_bell
    tag.svg(class: "tz-bell", viewBox: "0 0 16 16", width: 12, height: 12, fill: "none", stroke: "currentColor",
            "stroke-width": 1.6, "stroke-linecap": "round", "stroke-linejoin": "round", "aria-hidden": "true") do
      tag.path(d: "M4 11V7.5a4 4 0 0 1 8 0V11l1 1.5H3L4 11Z") + tag.path(d: "M6.5 14a1.6 1.6 0 0 0 3 0")
    end
  end

  def tz_cell_title(row, cell)
    time = "#{l(cell.local.to_date, format: :weekday_short)}, #{l(cell.local, format: :clock_24)} #{cell.local.zone}"
    names = cell.reachable_names
    title = names.any? ? t("grid.cell_title_names", zone: row.name, time:, names: short_names(names)) : t("grid.cell_title", zone: row.name, time:)
    [ title, clock_change_note(row, cell) ].compact.join("\n")
  end

  # "Clocks go back here (BST → GMT): 01:00 happens twice."
  def clock_change_note(row, cell)
    return if cell.shift.zero?

    from = Grid.zone_abbreviation(row.zone, cell.column.starts_at - 1)
    to = Grid.zone_abbreviation(row.zone, cell.column.starts_at)
    if cell.clocks_back?
      t("grid.clocks_back", from:, to:, time: l(cell.local, format: :clock_24))
    else # the hour the clocks jumped over, e.g. 02:00 when 01:00 is followed by 03:00
      t("grid.clocks_forward", from:, to:, time: l(cell.local - cell.shift, format: :clock_24))
    end
  end

  def clock_change_class(cell)
    "is-shift is-shift-#{cell.clocks_back? ? "back" : "forward"}" unless cell.shift.zero?
  end

  # "Ana, Ben and Cy", or the first few and "+N more" on big boards, so a
  # 1,000-person row doesn't repeat every name in every hour's title.
  def short_names(names)
    return names.to_sentence if names.size <= Grid::NAMES_SHOWN
    "#{names.first(Grid::NAMES_SHOWN).join(", ")} #{t("grid.more", count: names.size - Grid::NAMES_SHOWN)}"
  end

  # One row's hour strip and working-hours band depend only on these, so the
  # rendered HTML is cached and shared by everyone who sees the same row.
  def grid_lanes_cache_key(grid, row, anonymous)
    people = row.members.map { [ it.label, it.reachable_minutes ] }
    [ "grid-lanes", I18n.locale, grid.reference_zone.identifier, grid.starts_at.to_i, row.zone.identifier, row.name,
      anonymous, Digest::SHA256.hexdigest(people.to_json) ]
  end

  def tz_cell_content(cell)
    local = cell.local
    if cell.midnight?
      safe_join([ tag.span(l(local.to_date, format: "%a"), class: "dow"), tag.span(local.day, class: "dom") ])
    else
      minutes = local.min.zero? ? nil : tag.span(":%02d" % local.min, class: "mm")
      h12 = safe_join([ tag.span(safe_join([ l(local, format: :hour_12), minutes ])), tag.span(t(local.hour < 12 ? "time.am" : "time.pm"), class: "sfx") ])
      h24 = safe_join([ local.strftime("%H"), minutes ])
      safe_join([ tag.span(h12, class: "t12 flex flex-col items-center"), tag.span(h24, class: "t24") ])
    end
  end

  def avatar(member)
    hue = member.slack_user_id.to_s.sum % 360
    classes = [ "avatar" ]
    tag.span(class: classes, style: "--hue:#{hue}", title: member.label) do
      if avatar_src?(member.avatar_url)
        image_tag(member.avatar_url, alt: member.label, title: member.label, loading: "lazy", referrerpolicy: "no-referrer")
      else
        member.label.split.map { it[0] }.first(2).join.upcase
      end
    end
  end

  # Slack's image URLs, or the sample team's own files. Anything else would
  # be looked up as an asset (and raise), so it gets initials instead.
  def avatar_src?(url)
    url.to_s.match?(%r{\A(https://|/(?!/))})
  end

  # Every avatar names its person on hover, and "+N" lists who it stands for.
  def avatar_stack(members, limit: 3)
    tag.span(class: "avatars") do
      shown = members.first(limit).map { avatar(it) }
      if members.size > limit
        rest = members.drop(limit).map(&:label)
        shown << tag.span("+#{rest.size}", class: "avatar avatar-more", title: rest.join("\n"), "aria-label": t("grid.and_names", names: rest.to_sentence))
      end
      safe_join(shown)
    end
  end
end
