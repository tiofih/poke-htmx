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

  def test_design_system_core_classes
    content = style_content

    %w[
      topnav topnav-inner logo pagefoot
      btn btn-primary btn-secondary btn-ghost
      container section stack row row-between card
      eyebrow lead meta num muted
    ].each do |klass|
      assert_match(/\.#{Regexp.escape(klass)}\b/, content,
                   "expected style.css to define .#{klass}")
    end
  end

  def test_layout_uses_topnav_footer_shell
    layout = File.read(File.join(__dir__, "../views/layout.erb"))

    assert_match(/<header class="topnav">/, layout,
                 "expected layout.erb to open a <header class=\"topnav\">")
    assert_match(/<footer class="pagefoot">/, layout,
                 "expected layout.erb to open a <footer class=\"pagefoot\">")
    assert_match(%r{<link rel="stylesheet" href="/style\.css}, layout,
                 "expected layout.erb to link /style.css")
  end

  def test_body_gets_page_battle_history
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/battle", {}, user_session("user-a")
    end
    assert last_response.ok?
    assert_match(/class="[^"]*page-battle[^"]*"/, last_response.body,
                 "expected /battle body to have page-battle class")

    get "/history", {}, user_session("user-a")
    assert last_response.ok?
    assert_match(/class="[^"]*page-history[^"]*"/, last_response.body,
                 "expected /history body to have page-history class")

    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end
    assert last_response.ok?
    assert_match(/class="[^"]*page-list[^"]*"/, last_response.body,
                 "expected / body to keep page-list class")
  end

  def test_design_system_does_not_depend_on_sakura
    content = style_content
    block = content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]

    refute_nil block, "expected a delimited Open Design System block in style.css"
    refute_match(/sakura/i, block,
                 "design system must not depend on sakura resets")
    refute_match(/@import/, block,
                 "design system must not @import external stylesheets")
  end

  def test_style_css_route_serves_text_css
    get "/style.css"

    assert last_response.ok?, "expected GET /style.css to be 200"
    assert_match(%r{\Atext/css}, last_response.content_type,
                 "expected /style.css to respond with text/css")
  end
end
