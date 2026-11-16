ENV["FAKE_SLACK"] = "1"
require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ]

  setup { WebMock.disable_net_connect!(allow_localhost: true, allow: [ "chromedriver.storage.googleapis.com", /googlechromelabs/ ]) }
end
