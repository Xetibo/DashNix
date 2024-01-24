local ls = require("luasnip")
-- some shorthands...
local s = ls.s
local i = ls.i
local t = ls.t
local d = ls.dynamic_node
local c = ls.choice_node
local f = ls.function_node
local sn = ls.snippet_node

local fmt = require("luasnip.extras.fmt").fmt
local rep = require("luasnip.extras").rep

local snippets, autosnippets = {}, {}
local group = vim.api.nvim_create_augroup("Tex Snippets", { clear = true })
local file_pattern = "*.typst"
------------------------------------------------- boilerplate end
-- snippers go here:

local colorSnippet = s(
  "tx-",
  fmt([[ #text({1})[{2}] ]], {
    i(1, ""),
    i(2, ""),
  })
)
table.insert(snippets, colorSnippet)

local imageSnippet = s(
  "image-",
  fmt(
    [[
    #image("{1}", width: {2}%)
    ]],
    {
      i(1, "../../Screenshots/"),
      i(2, "100"),
    }
  )
)
table.insert(snippets, imageSnippet)

local centerImageSnippet = s(
  "cimage-",
  fmt(
    [[
    #align(center, [#image("{1}", width: {2}%)])
    ]],
    {
      i(1, "../../Screenshots/"),
      i(2, "100"),
    }
  )
)
table.insert(snippets, centerImageSnippet)

local colSnippet = s(
  "col-",
  fmt(
    [[
    #columns({1}, [{2}])
    ]],
    {
      i(1, ""),
      i(2, ""),
    }
  )
)
table.insert(snippets, colSnippet)

local codeSnippet = s(
  "code-",
  fmt(
    [[
    ```{1}
    {2}
    ```
    ]],
    {
      i(1, ""),
      i(2, ""),
    }
  )
)
table.insert(snippets, codeSnippet)

local patternSnippet = s(
  "pattern-",
  fmt(
    [[
    #subsection([{1}])
    #set text(size: 14pt)
    
    Problem | {2}
    Context | {3} 
    Participants :
    - {4}
    #set text(size: 11pt)
    // images
    {5}
    
    #columns(2, [
      #text(green)[Benefits]
      - {6}
      #colbreak()
      #text(red)[Liabilities]
      - {7}
    ])
    ]],
    {
      i(1, ""),
      i(2, ""),
      i(3, ""),
      i(4, ""),
      i(5, ""),
      i(6, ""),
      i(7, ""),
    }
  )
)
table.insert(snippets, patternSnippet)
------------------------------------------------- snippets end
return snippets, autosnippets
