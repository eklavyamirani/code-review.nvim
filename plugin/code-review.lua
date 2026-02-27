if vim.g.loaded_code_review then
  return
end
vim.g.loaded_code_review = true

vim.api.nvim_create_user_command("CodeReview", function()
  require("code-review").start()
end, { desc = "Start a code review session" })

vim.api.nvim_create_user_command("CodeReviewClose", function()
  require("code-review").close()
end, { desc = "Close the code review session" })

vim.api.nvim_create_user_command("CodeReviewSubmit", function()
  require("code-review").submit_review()
end, { desc = "Submit a PR review (approve/request changes/comment)" })

vim.api.nvim_create_user_command("CodeReviewRefresh", function()
  require("code-review").refresh()
end, { desc = "Refresh the current review session" })
