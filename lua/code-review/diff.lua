-- Unified diff parser for code-review.nvim
local M = {}

---@class DiffHunk
---@field old_start number Starting line in the old file
---@field old_count number Number of lines in the old file
---@field new_start number Starting line in the new file
---@field new_count number Number of lines in the new file
---@field header string The @@ header line
---@field lines DiffLine[] Lines in this hunk

---@class DiffLine
---@field type "context"|"add"|"remove" Line type
---@field text string Line content (without the +/- prefix)
---@field old_line number|nil Line number in old file
---@field new_line number|nil Line number in new file

---@class FileDiff
---@field old_file string Old file path
---@field new_file string New file path
---@field hunks DiffHunk[] List of hunks
---@field status string "added"|"deleted"|"modified"

--- Parse a unified diff into structured data
---@param raw string Raw unified diff output
---@return FileDiff[] files List of parsed file diffs
function M.parse(raw)
  local files = {}
  local current_file = nil
  local current_hunk = nil

  for line in raw:gmatch("[^\n]*") do
    -- File header: diff --git a/file b/file
    local old_path, new_path = line:match("^diff %-%-git a/(.+) b/(.+)$")
    if old_path then
      current_file = {
        old_file = old_path,
        new_file = new_path,
        hunks = {},
        status = "modified",
      }
      table.insert(files, current_file)
      current_hunk = nil
      goto continue
    end

    -- Detect new/deleted files
    if current_file then
      if line:match("^new file mode") then
        current_file.status = "added"
        goto continue
      end
      if line:match("^deleted file mode") then
        current_file.status = "deleted"
        goto continue
      end
    end

    -- Hunk header: @@ -old_start,old_count +new_start,new_count @@
    if current_file then
      local os, oc, ns, nc = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
      if os then
        current_hunk = {
          old_start = tonumber(os),
          old_count = tonumber(oc) or 1,
          new_start = tonumber(ns),
          new_count = tonumber(nc) or 1,
          header = line,
          lines = {},
        }
        table.insert(current_file.hunks, current_hunk)
        goto continue
      end
    end

    -- Diff lines
    if current_hunk then
      local prefix = line:sub(1, 1)
      local text = line:sub(2)

      if prefix == "+" then
        table.insert(current_hunk.lines, {
          type = "add",
          text = text,
          old_line = nil,
          new_line = nil, -- filled in below
        })
      elseif prefix == "-" then
        table.insert(current_hunk.lines, {
          type = "remove",
          text = text,
          old_line = nil,
          new_line = nil,
        })
      elseif prefix == " " then
        table.insert(current_hunk.lines, {
          type = "context",
          text = text,
          old_line = nil,
          new_line = nil,
        })
      end
      -- Skip \ No newline at end of file and other lines
    end

    ::continue::
  end

  -- Assign line numbers
  for _, file in ipairs(files) do
    for _, hunk in ipairs(file.hunks) do
      local old_line = hunk.old_start
      local new_line = hunk.new_start
      for _, diff_line in ipairs(hunk.lines) do
        if diff_line.type == "context" then
          diff_line.old_line = old_line
          diff_line.new_line = new_line
          old_line = old_line + 1
          new_line = new_line + 1
        elseif diff_line.type == "add" then
          diff_line.new_line = new_line
          new_line = new_line + 1
        elseif diff_line.type == "remove" then
          diff_line.old_line = old_line
          old_line = old_line + 1
        end
      end
    end
  end

  return files
end

return M
