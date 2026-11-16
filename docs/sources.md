# Sources

A source is where people and their time zones come from. Slack is the only
source in v1. Sources live in `app/lib/sources/` and subclass `Sources::Base`.

## The interface

```ruby
authorize_url(state:, redirect_uri:)   # where to send the browser to sign in
exchange(code:, redirect_uri:)         # => { token:, scopes:, workspace: {...}, person: {...} }
roster(token)                          # => [person, ...]
quiet_hours(token, external_ids)       # => { id => { enabled:, starts_at:, ends_at: } }, optional
groups(token)                          # => [{ external_id:, name:, handle:, member_ids: }], optional
```

Each group becomes a board for its members. Return `[]` if the source has no
notion of teams.

A person is a plain hash:

```ruby
{ external_id:, name:, display_name:, avatar_url:, tz:, tz_label:, tz_offset:, deleted:, is_bot: }
```

`tz` must be an IANA identifier such as `Europe/London`. Everything else in
the app (grouping, daylight, the grid) works from that.

Raise `Sources::Base::AuthError` when a token is revoked or expired (the token
is discarded), `Sources::Base::MissingScope` when it lacks a permission (the
token is kept), and
`Sources::Base::RateLimited` when the provider asks you to back off. Syncs rely
on both.

## Where v1 is Slack-specific

To add a second source, these places need to become source-aware:

- `Workspace#slack_team_id` and `Member#slack_user_id` should become a
  `source` + `external_id` pair.
- `SessionsController` hard-codes `Sources::Slack`.
- `Workspace#sync_*` instantiates `Sources::Slack`.

## Notes on likely next sources

**Google Calendar.** Signing in gives your own calendar's time zone. A
coworker's zone is available from `calendars.get` on their primary calendar
(their email) when their calendar is shared within the domain, which is the
Google Workspace default. There's no single roster call without admin access to
the Directory API, so a Google source would look people up by email, perhaps
seeded from Slack's `users:read.email`.

**Microsoft 365.** Any user can list the directory with `User.ReadBasic.All`,
but it exposes office location and city, not a time zone. Mailbox settings
(which include the zone) need `MailboxSettings.Read` per user. Likely needs a
city-to-zone mapping or admin consent.
