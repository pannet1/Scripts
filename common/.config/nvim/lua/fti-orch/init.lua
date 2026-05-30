local M = {}

local term_win = nil
local term_buf = nil
local last_raw_args = nil

function M.run(raw_args)
  last_raw_args = raw_args

  local cmd_base = vim.fn.getcwd() .. "/.agents/orchestrator.py"

  local args = vim.split(raw_args, "%s+")
  local first = args[1] or ""
  local prefix = first:match("^(%w+)/") or ""

  local cmd = cmd_base .. " " .. raw_args

  if not raw_args:match("%-%-prompt") then
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local content = table.concat(lines, "\n"):gsub("%s+$", "")
    if content ~= "" then
      local tmpfile = os.tmpname() .. ".md"
      local file = io.open(tmpfile, "w")
      if file then
        file:write(content)
        file:close()
        cmd = cmd_base .. " " .. first .. " --prompt " .. tmpfile
      end
    end
  end

  local prev_win = vim.api.nvim_get_current_win()

  if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
    local chan = vim.api.nvim_buf_get_var(term_buf, "terminal_job_id")
    vim.fn.chansend(chan, cmd .. "\n")
    vim.api.nvim_set_current_win(prev_win)
    return
  end

  vim.cmd("belowright split | terminal")
  term_buf = vim.api.nvim_get_current_buf()
  term_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(term_win, 10)
  vim.api.nvim_set_current_win(prev_win)

  vim.api.nvim_buf_attach(term_buf, false, {
    on_detach = function()
      term_win = nil
      term_buf = nil
    end,
  })

  vim.fn.jobwait({}, 100)
  local chan = vim.api.nvim_buf_get_var(term_buf, "terminal_job_id")
  vim.fn.chansend(chan, cmd .. "\n")
end

function M.last()
  if last_raw_args then
    M.run(last_raw_args)
  else
    print("[orchestrator] No previous command.")
  end
end

function M.toggle()
  if term_win and vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_win_close(term_win, true)
    term_win = nil
    term_buf = nil
  end
end

vim.api.nvim_create_user_command("Orch", function(opts)
  M.run(opts.args)
end, { nargs = 1, desc = "Run orchestrator: new/X / do/X / modify/X / bugfix/X / delete/X" })

vim.api.nvim_create_user_command("OrchLast", function()
  M.last()
end, {})

vim.api.nvim_create_user_command("OrchToggle", function()
  M.toggle()
end, {})

vim.keymap.set("n", "<leader>or", "<cmd>OrchLast<CR>", { desc = "Re-run last orchestrator command" })
vim.keymap.set("n", "<leader>ot", "<cmd>OrchToggle<CR>", { desc = "Toggle orchestrator terminal" })
vim.keymap.set("n", "<leader>os", '<cmd>Orch new/<CR>', { desc = "Scaffold (type: Orch new/X --prompt ...)" })
vim.keymap.set("n", "<leader>oi", '<cmd>Orch do/<CR>', { desc = "Implement (type: Orch do/X)" })

print("[orchestrator] Loaded. :Orch feature/modify/bugfix/X reads current buffer as prompt.")
