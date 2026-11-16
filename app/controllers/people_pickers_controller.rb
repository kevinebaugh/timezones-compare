# The "Compare people" list: every coworker in the workspace, loaded into the
# picker only when it's opened. You come first, then whoever the board you're
# on already has, so they're easy to untick; then everyone else.
class PeoplePickersController < ApplicationController
  def show
    @picked = Array(params[:p]).flat_map { it.to_s.split(",") }
    @me = Current.user.member
    # You're ticked for a new comparison, and as the link has it when editing one.
    @me_picked = @picked.empty? || @picked.include?(@me.slack_user_id)
    picked, @rest = Current.user.workspace.members.colleagues.where.not(id: @me.id).alphabetical
                           .partition { @picked.include?(it.slack_user_id) }
    @picked_people = picked
  end
end
