return {
  {
    "williamboman/mason.nvim",
    lazy = false,
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    opts = {
      auto_install = true
    }
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      'saghen/blink.cmp',
    },
    lazy = false,
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      local lspconfig = require("lspconfig")
      lspconfig.lua_ls.setup{
        capabilities = capabilities
      }
      lspconfig.ts_ls.setup{
        capabilities = capabilities
      }
      lspconfig.html.setup{
        capabilities = capabilities
      }

      vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, {})
      vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, {})

        -- Show diagnostics inline and on hover
      vim.diagnostic.config({
        virtual_text = {
          prefix = "●",
          spacing = 2,
        },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
      })

      vim.o.updatetime = 250
      -- vim.api.nvim_create_autocmd("CursorHold", {
      --  callback = function()
      --    vim.diagnostic.open_float(nil, { focus = false })
      --  end,
      -- })
    end,
  },
}

