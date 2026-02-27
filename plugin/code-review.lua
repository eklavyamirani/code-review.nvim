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

vim.api.nvim_create_user_command("CodeReviewAsk", function()
  require("code-review").ask_ai()
end, { desc = "Ask AI for review assistance" })

vim.api.nvim_create_user_command("CodeReviewSet", function(opts)
  local args = vim.split(opts.args, "%s+", { trimempty = true })
  if #args < 2 then
    vim.notify("Usage: :CodeReviewSet key value", vim.log.levels.WARN)
    return
  end
  local key = args[1]
  local value = table.concat(vim.list_slice(args, 2), " ")
  require("code-review").set_config(key, value)
end, { desc = "Set a config value at runtime", nargs = "+" })

vim.api.nvim_create_user_command("CodeReviewCheckout", function(opts)
  local ref_type = opts.args
  if ref_type ~= "base" and ref_type ~= "head" then
    vim.notify("Usage: :CodeReviewCheckout base|head", vim.log.levels.WARN)
    return
  end
  require("code-review").checkout_file(ref_type)
end, { desc = "Open current file at base or head ref", nargs = 1, complete = function()
  return { "base", "head" }
end })

vim.api.nvim_create_user_command("CodeReviewInfo", function()
  require("code-review").show_pr_info()
end, { desc = "Show PR description and metadata" })
