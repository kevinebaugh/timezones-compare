# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_21_170045) do
  create_table "board_visits", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "board_key", null: false
    t.float "score", default: 0.0, null: false
    t.datetime "visited_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "board_key"], name: "index_board_visits_on_user_id_and_board_key", unique: true
    t.index ["user_id"], name: "index_board_visits_on_user_id"
  end

  create_table "channel_memberships", force: :cascade do |t|
    t.integer "channel_id", null: false
    t.integer "member_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_id", "member_id"], name: "index_channel_memberships_on_channel_id_and_member_id", unique: true
    t.index ["channel_id"], name: "index_channel_memberships_on_channel_id"
    t.index ["member_id"], name: "index_channel_memberships_on_member_id"
  end

  create_table "channels", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.string "slack_channel_id", null: false
    t.string "name", null: false
    t.integer "num_members", default: 0, null: false
    t.datetime "members_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id", "name"], name: "index_channels_on_workspace_id_and_name"
    t.index ["workspace_id", "slack_channel_id"], name: "index_channels_on_workspace_id_and_slack_channel_id", unique: true
    t.index ["workspace_id"], name: "index_channels_on_workspace_id"
  end

  create_table "group_memberships", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "member_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id", "member_id"], name: "index_group_memberships_on_group_id_and_member_id", unique: true
    t.index ["group_id"], name: "index_group_memberships_on_group_id"
    t.index ["member_id"], name: "index_group_memberships_on_member_id"
  end

  create_table "groups", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.string "slack_group_id", null: false
    t.string "name", null: false
    t.string "handle", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "slack_updated_at"
    t.index ["workspace_id", "handle"], name: "index_groups_on_workspace_id_and_handle"
    t.index ["workspace_id", "slack_group_id"], name: "index_groups_on_workspace_id_and_slack_group_id", unique: true
    t.index ["workspace_id"], name: "index_groups_on_workspace_id"
  end

  create_table "members", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.string "slack_user_id", null: false
    t.string "name", null: false
    t.string "display_name"
    t.string "avatar_url"
    t.string "tz"
    t.string "tz_label"
    t.integer "tz_offset"
    t.boolean "deleted", default: false, null: false
    t.boolean "is_bot", default: false, null: false
    t.boolean "dnd_enabled", default: false, null: false
    t.datetime "dnd_starts_at"
    t.datetime "dnd_ends_at"
    t.datetime "dnd_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "guest", default: false, null: false
    t.string "email"
    t.index ["workspace_id", "slack_user_id"], name: "index_members_on_workspace_id_and_slack_user_id", unique: true
    t.index ["workspace_id"], name: "index_members_on_workspace_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "member_id", null: false
    t.text "slack_user_token"
    t.string "token_scopes"
    t.datetime "last_signed_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "tab_order"
    t.date "tab_order_on"
    t.datetime "channels_synced_at"
    t.index ["member_id"], name: "index_users_on_member_id", unique: true
  end

  create_table "workspaces", force: :cascade do |t|
    t.string "slack_team_id", null: false
    t.string "name", null: false
    t.string "domain"
    t.datetime "roster_synced_at"
    t.datetime "availability_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_viewed_at"
    t.index ["last_viewed_at"], name: "index_workspaces_on_last_viewed_at"
    t.index ["slack_team_id"], name: "index_workspaces_on_slack_team_id", unique: true
  end

  add_foreign_key "board_visits", "users"
  add_foreign_key "channel_memberships", "channels"
  add_foreign_key "channel_memberships", "members"
  add_foreign_key "channels", "workspaces"
  add_foreign_key "group_memberships", "groups"
  add_foreign_key "group_memberships", "members"
  add_foreign_key "groups", "workspaces"
  add_foreign_key "members", "workspaces"
  add_foreign_key "users", "members"
end
