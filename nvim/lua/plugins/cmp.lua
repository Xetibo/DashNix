return {
  {
    "L3MON4D3/LuaSnip",
    build = (not jit.os:find("Windows"))
        and "echo -e 'NOTE: jsregexp is optional, so not a big deal if it fails to build\n'; make install_jsregexp"
      or nil,
    dependencies = {
      "rafamadriz/friendly-snippets",
      config = function()
        require("luasnip.loaders.from_vscode").lazy_load()
      end,
    },
    opts = {
      history = true,
      delete_check_events = "TextChanged",
      updateevents = "TextChanged,TextChangedI",
      enable_autosnippets = true,
    },
    keys = function()
      return {}
    end,
    config = function(_, opts)
      require("luasnip").setup(opts)
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "FelipeLema/cmp-async-path",
      "saadparwaiz1/cmp_luasnip",
      "Saecki/crates.nvim",
    },
    opts = function()
      vim.api.nvim_set_hl(0, "CmpGhostText", { link = "Comment", default = true })
      local cmp = require("cmp")
      local defaults = require("cmp.config.default")()
      local luasnip = require("luasnip")
      return {
        preselect = cmp.PreselectMode.None,
        completion = {
          -- completeopt = "menu,menuone,noinsert",
        },
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = {
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = false }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
          ["<S-CR>"] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Replace,
            select = false,
          }), -- Accept cur
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert })
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item({ behavior = cmp.SelectBehavior.Insert })
            else
              fallback()
            end
          end, {
            "i",
            "s",
          }),
          ["<C-j>"] = cmp.mapping(function(fallback)
            if luasnip.expandable() then
              luasnip.expand()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, {
            "i",
            "s",
          }),
          ["<C-k>"] = cmp.mapping(function(fallback)
            if luasnip.expand_or_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, {
            "i",
            "s",
          }),
        },
        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = 99 },
          { name = "luasnip", priority = 3, max_item_count = 3 },
          { name = "buffer", priority = 2, max_item_count = 2, keyword_length = 5 },
          { name = "async_path", priority = 1, max_item_count = 2, keyword_length = 3, trigger_characters = {} },
          { name = "crates" },
        }),
        -- sorting = {
        --   priority_weight = 90,
        --   comparators = {
        --     compare.exact,
        --     compare.score,
        --     compare.offset,
        --     compare.kind,
        --   },
        -- },
        -- formatting = {
        --   preselect = cmp.PreselectMode.None,
        --   format = function(entry, item)
        --     local icons = require("lazyvim.config").icons.kinds
        --     if icons[item.kind] then
        --       item.kind = icons[item.kind] .. item.kind
        --     end
        --     return require("tailwindcss-colorizer-cmp").formatter(entry, item)
        --   end,
        -- },
        experimental = {
          ghost_text = {
            hl_group = "CmpGhostText",
          },
        },
        sorting = defaults.sorting,
      }
    end,
    -- config = function(_, opts)
    --   local cmp = require("cmp")
    --   require("luasnip.loaders.from_lua").load({ paths = "~/.config/nvim/snippets" })
    --   cmp.setup(opts)
    -- end,
  },
}
