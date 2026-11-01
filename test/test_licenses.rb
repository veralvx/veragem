# frozen_string_literal: true

require "test_helper"

# A licence, as an option or an answer gives it: in any case, as its SPDX expression or abbreviated
# where one alone starts so.
class TestLicenses < Minitest::Test
  include Veragem::TerminalSupport

  TAKEN = { "MIT" => "mit", "Ap" => "apache", "d" => "dual", "dual" => "dual", "Apache-2.0" => "apache",
            "mit or apache-2.0" => "dual", "Apache-2.0 OR MIT" => "dual", " mit " => "mit" }.freeze

  def test_an_option_takes_one_in_any_case_as_spdx_or_abbreviated
    TAKEN.each { |given, license| assert_equal license, parse("my_gem", "--license=#{given}").license }
  end

  def test_an_answer_takes_one_alike
    TAKEN.each do |given, license|
      gem, = ask("my_gem", "--no-exe", "--no-citation", answers: [given, "", "", "", ""])

      assert_equal license, gem.license
    end
  end

  # what is refused names the choices; "", or a start several share, is no licence
  def test_one_refused_names_the_choices
    ["gpl", "", "MITX", "MIT OR", "MIT OR MIT"].each do |given|
      error = assert_raises(Veragem::Error) { parse("my_gem", "--license=#{given}") }

      assert_equal "invalid license (mit, apache or dual) #{given.inspect}", error.message
    end
  end
end
