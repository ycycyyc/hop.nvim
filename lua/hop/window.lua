local hint = require'hop.hint'

local M = {}

local function window_context(win_handle, cursor_pos)
  -- get a bunch of information about the window and the cursor
  local win_info = vim.fn.getwininfo(win_handle)[1]
  local win_view = vim.fn.winsaveview()
  local top_line = win_info.topline - 1
  local bot_line = win_info.botline

  -- NOTE: due to an (unknown yet) bug in neovim, the sign_width is not correctly reported when shifting the window
  -- view inside a non-wrap window, so we can’t rely on this; for this reason, we have to implement a weird hack that
  -- is going to disable the signs while hop is running (I’m sorry); the state is restored after jump
  -- local left_col_offset = win_info.variables.context.number_width + win_info.variables.context.sign_width
  local win_width = nil

  -- hack to get the left column offset in nowrap
  if not vim.wo.wrap then
    vim.api.nvim_win_set_cursor(win_handle, { cursor_pos[1], 0 })
    local left_col_offset = vim.fn.wincol() - 1
    vim.fn.winrestview(win_view)
    win_width = win_info.width - left_col_offset
  end

  return {
    hwin=win_handle,
    cursor_pos=cursor_pos,
    top_line=top_line,
    bot_line=bot_line,
    win_width=win_width,
    col_offset=win_view.leftcol
  }
end

-- Collect all multi-windows's context:
--
-- {
--   { -- context list that each contains one buffer
--      hbuf = <buf-handle>,
--      { -- windows list that display the same buffer
--         hwin = <win-handle>,
--         ...
--      },
--      ...
--   },
--   ...
-- }
function M.get_window_context(multi_windows)
  local all_ctxs = {}

  -- Generate contexts of windows
  local cur_hwin = vim.api.nvim_get_current_win()
  local cur_hbuf = vim.api.nvim_win_get_buf(cur_hwin)
  all_ctxs[#all_ctxs + 1] = {
    hbuf = cur_hbuf,
    window_context(cur_hwin, vim.api.nvim_win_get_cursor(cur_hwin)),
  }

  if not multi_windows then
    return all_ctxs
  end

  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    if w ~= cur_hwin then

      -- Check duplicated buffers
      local bctx = nil
      for _, _bctx in ipairs(all_ctxs) do
        if b == _bctx.hbuf then
          bctx = _bctx
          break
        end
      end

      if bctx then
        bctx[#bctx + 1] = window_context(w, vim.api.nvim_win_get_cursor(w))
      else
        all_ctxs[#all_ctxs + 1] = {
          hbuf = b,
          window_context(w, vim.api.nvim_win_get_cursor(w))
        }
      end

    end
  end

  -- Move cursor back to current window
  vim.api.nvim_set_current_win(cur_hwin)

  return all_ctxs
end

-- Clip the window context based on the direction.
--
-- If the direction is HintDirection.BEFORE_CURSOR, then everything after the cursor will be clipped.
-- If the direction is HintDirection.AFTER_CURSOR, then everything before the cursor will be clipped.
function M.clip_window_context(context, direction)
  if direction == hint.HintDirection.BEFORE_CURSOR then
    context.bot_line = context.cursor_pos[1] - 1
  elseif direction == hint.HintDirection.AFTER_CURSOR then
    context.top_line = context.cursor_pos[1] - 1
  end
end

return M
