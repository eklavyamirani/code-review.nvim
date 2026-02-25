-- Test configuration for code-review.nvim
-- Controls whether tests use real API calls or mocks
local M = {}

-- Set to true to use real gh API calls (requires GH_TOKEN with write access)
-- Default false: uses mocked responses for write operations
M.use_real_api = os.getenv("CODE_REVIEW_TEST_REAL_API") == "1"

-- Repository to test against
M.test_repo = os.getenv("CODE_REVIEW_TEST_REPO") or "eklavyamirani/code-review.nvim"

-- PR number to test against
M.test_pr = tonumber(os.getenv("CODE_REVIEW_TEST_PR")) or 1

return M
