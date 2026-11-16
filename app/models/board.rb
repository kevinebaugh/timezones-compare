# A board is a view, not a stored list: "Everyone" in the workspace, the
# people in one of its Slack user groups (👥), or the members of one of its
# public channels (#). Membership follows Slack. Your own groups are tabs, and
# so are channels you're in once you've opened them. Any other group or public
# channel can be opened too, as in Slack, where full members can see them all.
#
# A people board (👤) is exactly the people picked (you too, if ticked), in the link
# (?p=U1,U2), so it can be shared with teammates in the same workspace.
class Board
  EVERYONE = "everyone".freeze
  PEOPLE = "people".freeze
  MAX_PICKED = 50

  attr_reader :key, :name, :group, :channel, :picked

  def self.everyone(user) = new(user, key: EVERYONE, name: user.workspace.name)

  # The whole workspace first, then your groups and the channels you've opened:
  # the ones you open most (and most recently) first, then by recent activity
  # in Slack. The order is worked out once a day and held, so tabs never move
  # while you click them. New ones go at the end; ones you've left drop out.
  def self.all_for(user, today: user.local_today)
    boards = my_groups(user).map { from_group(user, it) } + opened_channels(user).map { from_channel(user, it) }
    user.refresh_tab_order!(rank(user, boards), on: today) unless user.tab_order_on == today

    position = Array(user.tab_order).each_with_index.to_h
    [ everyone(user) ] + boards.sort_by { [ position.fetch(it.key, position.size), it.name.downcase ] }
  end

  def self.rank(user, boards)
    scores = BoardVisit.where(user:).to_h { [ it.board_key, it.decayed_score ] }
    boards.sort_by { [ -scores.fetch(it.key, 0), -(it.group&.slack_updated_at&.to_i || 0), it.name.downcase ] }.map(&:key)
  end

  def self.find_for(user, key, picked: nil)
    return everyone(user) if key == EVERYONE
    return for_people(user, picked) if key == PEOPLE

    if key.start_with?(Channel::KEY_PREFIX)
      channel = user.workspace.channels.find_by(name: key.delete_prefix(Channel::KEY_PREFIX))
      from_channel(user, channel) if channel
    else
      group = user.workspace.groups.find_by(handle: key)
      from_group(user, group) if group
    end
  end

  # Everything that isn't a tab, for "More groups and channels": [board, size]
  # pairs. Groups alphabetically; channels by size, biggest first.
  def self.others_for(user, tabs: all_for(user))
    tabs = tabs.map(&:key)
    mine = mine_ids(user)

    group_counts = user.workspace.members.people.joins(:group_memberships)
                       .where.not(group_memberships: { group_id: GroupMembership.where(member_id: user.member_id).select(:group_id) })
                       .group("group_memberships.group_id").count
    groups = user.workspace.groups.where(id: group_counts.keys).sort_by { it.name.downcase }
                 .map { [ from_group(user, it), group_counts.fetch(it.id) ] }

    # Channels biggest first, so busy shared channels beat one-off incident rooms.
    channels = user.workspace.channels.where("num_members > 0").sort_by { [ -it.num_members, it.name ] }.map { [ from_channel(user, it), it.num_members ] }
                   .reject { |board, _| tabs.include?(board.key) }
    yours, others = channels.partition { |board, _| mine.include?(board.channel.id) }

    { your_channels: yours, groups:, channels: others }
  end

  def self.my_groups(user)
    Group.joins(:group_memberships).where(group_memberships: { member_id: user.member_id }).to_a
  end

  # Channels you're in that you've opened at least once.
  def self.opened_channels(user)
    opened = BoardVisit.where(user:).where("board_key LIKE ?", "#{Channel::KEY_PREFIX}%")
                       .pluck(:board_key).map { it.delete_prefix(Channel::KEY_PREFIX) }
    return [] if opened.empty?

    user.workspace.channels.joins(:channel_memberships)
        .where(channel_memberships: { member_id: user.member_id }, name: opened).to_a
  end

  def self.mine_ids(user)
    ChannelMembership.where(member_id: user.member_id).pluck(:channel_id)
  end

  # Coworkers picked by Slack id (a list, or "U1,U2"), in this workspace only.
  def self.for_people(user, ids)
    ids = Array(ids).flat_map { it.to_s.split(",") }.map(&:strip).reject(&:blank?).uniq.first(MAX_PICKED)
    picked = user.workspace.members.people.where(slack_user_id: ids).alphabetical.to_a
    return if picked.empty?

    # Named after the others; "you" only when it's just you.
    others = picked.reject { it.id == user.member_id }.presence || picked
    shown = others.first(3).map(&:label)
    name = shown.join(", ") + (others.size > 3 ? " +#{others.size - 3}" : "")
    new(user, key: PEOPLE, name:, picked:)
  end

  def self.from_group(user, group) = new(user, key: group.handle, name: group.name, group:)
  def self.from_channel(user, channel) = new(user, key: channel.key, name: channel.name, channel:)

  def initialize(user, key:, name:, group: nil, channel: nil, picked: nil)
    @user = user
    @key = key
    @name = name
    @group = group
    @channel = channel
    @picked = picked
  end

  def to_param = key
  def people? = !picked.nil?
  def everyone? = group.nil? && channel.nil? && !people?

  # Extra link parameters that identify this board (the people picked).
  def query = people? ? { p: picked.map(&:slack_user_id).join(",") } : {}
  def ==(other) = other.is_a?(Board) && other.key == key

  def member?
    return true if everyone? || people?
    return group.group_memberships.exists?(member_id: @user.member_id) if group

    channel.channel_memberships.exists?(member_id: @user.member_id)
  end

  # Everyone shown on the grid. Guests only appear in groups and channels
  # they're in, and the viewer always appears on their own Everyone board.
  def members
    scope = @user.workspace.members.people
    if everyone?
      scope.where(guest: false).or(scope.where(id: @user.member_id))
    elsif people?
      scope.where(id: picked.map(&:id))
    elsif group
      scope.where(id: group.group_memberships.select(:member_id))
    else
      scope.where(id: channel.channel_memberships.select(:member_id))
    end
  end
end
