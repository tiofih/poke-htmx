# frozen_string_literal: true

require_relative "server_test_helpers"

# Testes estruturais do Design System base (sessão 0072) — provam C1-C6.
# Base aditiva: tokens oklch + classes-núcleo no style.css + shell do layout.erb.
class DesignSystemTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def style_content
    File.read(File.join(__dir__, "../public/style.css"))
  end

  def test_design_system_root_tokens_oklch
    content = style_content
    root = content[/:root\s*\{.*?\n\}/m]

    refute_nil root, "expected style.css to define a :root block"
    assert_match(/--bg:\s*oklch\(21%\s*0\.05\s*165\)/, root)
    assert_match(/--accent:\s*oklch\(66%\s*0\.17\s*150\)/, root)
    assert_match(/--surface:\s*oklch/, root)
    assert_match(/--fg:\s*oklch/, root)
    assert_match(/--border:\s*oklch/, root)
    assert_match(/--font-display:/, root)
    assert_match(/--radius:/, root)
    assert_match(/--container:/, root)
  end
end
