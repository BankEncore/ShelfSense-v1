# frozen_string_literal: true

require "json"
require "fileutils"
require "axe-capybara"
require "axe/api/run"
require "axe/core"
require "webdriver_script_adapter/execute_async_script_adapter"

module UdsEvidenceHelpers
  BLOCKER_IMPACTS = %w[critical serious].freeze

  UDS_VIEWPORTS = [
    { width: 1280, height: 720, zoom: 1, label: "1280x720" },
    { width: 1440, height: 900, zoom: 1, label: "1440x900" },
    { width: 320, height: 568, zoom: 1, label: "320x568" }
  ].freeze

  UDS_ZOOM_LEVELS = [ 2, 4 ].freeze

  def configure_axe!
    Axe::Configuration.instance.page = page
  end

  def assert_axe_clean(surface:, exclude_rules: [], context: nil)
    configure_axe!
    run = Axe::API::Run.new
    run = run.within(context) if context.present?
    run = run.skipping(*exclude_rules) if exclude_rules.any?
    audit = Axe::Core.new(page).call(run)
    violations = audit.results.violations.reject do |rule|
      allowed_axe_violation?(surface: surface, rule_id: rule.id)
    end
    blockers = violations.select { |rule| BLOCKER_IMPACTS.include?(rule.impact) }
    capture_uds_evidence(surface: surface, state: "axe_failure", extra: { violations: blockers.map(&:id) }) if blockers.any?
    assert blockers.empty?, axe_failure_message(surface: surface, violations: blockers, audit: audit)
  end

  def assert_focus_sequence(selectors)
    selectors.each do |selector|
      find(selector).click
      assert page.evaluate_script(<<~JS), "Expected focus on #{selector}"
        (function() {
          var el = document.querySelector(#{selector.to_json});
          return el && document.activeElement === el;
        })()
      JS
    end
  end

  def assert_layout_usable(surface:, scroll_selector: ".table-scroll", check_overflow: true, check_clipped: true)
    if check_overflow
      body_overflow = page.evaluate_script(<<~JS)
        (function() {
          var root = document.querySelector("main, .app-content, .ops-content, .pos-shell, .pos-history, .pos-workspace") || document.documentElement;
          if (root.scrollWidth <= root.clientWidth + 2) return false;
          var scroll = document.querySelector(#{scroll_selector.to_json}) ||
            document.querySelector(".pos-lines, .pos-history__table");
          if (scroll && scroll.scrollWidth > scroll.clientWidth + 2) return false;
          return true;
        })()
      JS
      assert_not body_overflow, "#{surface}: page has horizontal overflow"
    end

    if page.has_css?(scroll_selector, wait: 0)
      scroll_visible = page.evaluate_script(<<~JS)
        (function() {
          var region = document.querySelector(#{scroll_selector.to_json});
          if (!region) return false;
          var rect = region.getBoundingClientRect();
          return rect.width > 0 && rect.height > 0;
        })()
      JS
      assert scroll_visible, "#{surface}: scroll region #{scroll_selector} is not visible"
    end

    if check_clipped
      clipped_actions = page.evaluate_script(<<~JS)
      (function() {
        var root = document.querySelector("main, .app-content, .ops-content, .pos-workspace") || document.body;
        var buttons = Array.from(root.querySelectorAll("button, a.button, input[type='submit'], .btn, a.btn"));
        return buttons.filter(function(el) {
          if (el.offsetParent === null) return false;
          var rect = el.getBoundingClientRect();
          return rect.bottom <= 0 || rect.top >= window.innerHeight || rect.right <= 0 || rect.left >= window.innerWidth;
        }).map(function(el) { return el.textContent.trim().slice(0, 40); });
      })()
      JS
      assert clipped_actions.empty?, "#{surface}: clipped actions: #{clipped_actions.join(', ')}"
    end
  end

  def assert_reduced_motion_smoke(surface:)
    with_emulated_media("prefers-reduced-motion" => "reduce") do
      durations = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll("*")).slice(0, 500).map(function(el) {
          return window.getComputedStyle(el).transitionDuration;
        }).filter(function(v) { return v && v !== "0s" && v !== "0ms"; })
      JS
      assert durations.empty?, "#{surface}: transitions remain under reduced motion: #{durations.uniq.first(5)}"
    end
  end

  def assert_forced_colors_smoke(surface:)
    with_emulated_media("forced-colors" => "active") do
      assert_selector "body", visible: :all
      assert page.evaluate_script("document.body.innerText.length > 0"), "#{surface}: forced-colors body empty"
    end
  end

  def with_emulated_media(features)
    payload = {
      features: features.map { |name, value| { name: name.to_s, value: value.to_s } }
    }
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", **payload)
    yield
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  def capture_uds_evidence(surface:, state:, extra: {})
    sha = ENV.fetch("UDS_EVIDENCE_SHA") { `git rev-parse HEAD`.strip }
    dir = Rails.root.join("tmp/uds-evidence", sha, surface.to_s)
    FileUtils.mkdir_p(dir)
    metadata = {
      surface: surface,
      state: state,
      url: current_url,
      viewport: page.driver.browser.manage.window.size.to_h,
      captured_at: Time.current.utc.iso8601
    }.merge(extra)
    File.write(dir.join("#{state}.json"), JSON.pretty_generate(metadata))
  rescue StandardError
    nil
  end

  def uds_layout_smoke(surface:, scroll_selector: ".table-scroll", required_selectors: [], check_clipped: true)
    with_viewport(width: 1280, height: 720) do
      assert_layout_usable(surface: surface, scroll_selector: scroll_selector, check_clipped: check_clipped)
    end

    UDS_VIEWPORTS.each do |viewport|
      next if viewport[:label] == "1280x720"

      with_viewport(**viewport.slice(:width, :height, :zoom)) do
        required_selectors.each do |selector|
          if selector.start_with?("text:")
            assert_text selector.delete_prefix("text:")
          else
            assert_selector selector
          end
        end
      end
    end

    UDS_ZOOM_LEVELS.each do |zoom|
      with_viewport(width: 1280, height: 720, zoom: zoom) do
        required_selectors.each do |selector|
          if selector.start_with?("text:")
            assert_text selector.delete_prefix("text:")
          else
            assert_selector selector
          end
        end
      end
    end
  end

  private

  def allowed_axe_violations
    @allowed_axe_violations ||= begin
      path = Rails.root.join("test/support/uds_axe_allowlist.yml")
      File.exist?(path) ? YAML.load_file(path) : {}
    end
  end

  def allowed_axe_violation?(surface:, rule_id:)
    Array(allowed_axe_violations[surface.to_s]).include?(rule_id)
  end

  def axe_failure_message(surface:, violations:, audit:)
    lines = violations.map { |rule| "#{rule.id} (#{rule.impact}): #{rule.help}" }
    [ "UDS axe blockers on #{surface}:", *lines, audit.failure_message ].join("\n")
  end
end
