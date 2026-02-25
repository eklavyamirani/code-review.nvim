if vim.g.loaded_code_review then
  return
end
vim.g.loaded_code_review = true

vim.api.nvim_create_user_command("CodeReview", function()
  require("code-review").setup()
  -- TODO: start review session
end, { desc = "Start a code review session" })

vim.api.nvim_create_user_command("CodeReviewClose", function()
  -- TODO: close review session
end, { desc = "Close the code review session" })
