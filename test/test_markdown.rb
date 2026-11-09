# frozen_string_literal: true

require "test_helper"

class TestMarkdown < Minitest::Test
  # shields.io's static badge: a dash or an underscore doubled, the rest URL-encoded
  def test_a_badge_is_a_static_shields_badge
    { ["license", "MIT OR Apache-2.0", "blue"] => "https://img.shields.io/badge/license-MIT%20OR%20Apache--2.0-blue",
      ["ruby", ">= 4.0", "red"] => "https://img.shields.io/badge/ruby-%3E%3D%204.0-red",
      %w[a_b c/d blue] => "https://img.shields.io/badge/a__b-c%2Fd-blue" }.each do |args, url|
      assert_equal url, Veragem::Markdown.badge(*args)
    end
  end
end
