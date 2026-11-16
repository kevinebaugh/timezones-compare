require "test_helper"

class ClientErrorsControllerTest < ActionDispatch::IntegrationTest
  test "reports a browser error without signing in" do
    assert_error_reported(ClientErrorsController::BrowserError) do
      post client_errors_path, params: { message: "x is undefined", source: "/assets/grid.js", line: 12, column: 4, path: "/boards/everyone", kind: "error" }
    end
    assert_response :no_content
  end

  test "an empty report still answers quietly" do
    post client_errors_path
    assert_response :no_content
  end
end
