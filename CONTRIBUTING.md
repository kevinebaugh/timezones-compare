# Contributing

Thanks for helping. A few notes:

- `FAKE_SLACK=1 bin/dev` gives you a working app with seeded people. You don't need a Slack app to work on the UI.
- Run `bin/rails test`, `bin/rubocop`, and `bin/brakeman` before opening a PR. CI runs all three.
- The grid's correctness lives in `app/models/grid.rb` and `app/lib/daylight.rb`. Time math changes need tests, especially around DST and half-hour zones.
- Keep the tone inclusive. The app shows daylight and people's own notification schedules, never assumed "working hours."
- New sources: see `docs/sources.md`.
