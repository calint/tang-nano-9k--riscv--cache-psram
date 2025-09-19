return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        verible = {
          cmd = {
            "verible-verilog-ls",
            "--rules_config_search=true"
          },
        },
      },
    },
  },
}
