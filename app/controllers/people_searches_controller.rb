# Coworkers for the groups-and-channels menu's search, so typing a name there
# finds a person too. Loaded only when the menu opens; each opens a board of
# you and them.
class PeopleSearchesController < ApplicationController
  def show
    @me = Current.user.member
    @people = Current.user.workspace.members.colleagues.where.not(id: @me.id).alphabetical
  end
end
