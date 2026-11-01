# frozen_string_literal: true

require "test_helper"

# The probe: a Ruby of its own that tells what a gem's modules and file would meet.
class TestProbe < Minitest::Test
  include Veragem::TestSupport

  # in a Ruby of its own: nothing the library prints is taken for an answer, and it loads with no
  # arguments, in an empty directory; nothing is within a constant no module
  def test_the_probe_requires_the_top_level_library_alone
    assert_equal ["", "", "Module", "Class"], Veragem::Name.probe("date", "my_gem", %w[Comparable Date])
    in_tmpdir do |dir|
      noisy = File.join(dir, "noisy.rb")
      File.write(noisy, "puts 'Class'\nwarn 'Class'\nNoisy = 1\nCleared = 1 if ARGV.empty?\n" \
                        "Scratch = 1 if Dir.empty?('.')\n")

      assert_equal ["", "", "Integer", "", "", "Integer", "Integer"],
                   Veragem::Name.probe(noisy, "my_gem", %w[Noisy Quiet Noisy::Inner Cleared Scratch])
    end
  end

  def test_the_probe_is_asked_once_a_process
    answers = Veragem::Name.probe("date", "probed_once", %w[ProbedOnce])

    assert_same answers, Veragem::Name.probe("date", "probed_once", %w[ProbedOnce])
  end

  # RUBYOPT's options would print before the answers: a Ruby started with it -- outside this bundle,
  # whose Bundler would restore the RUBYOPT it saw first -- keeps it from the probe's child
  def test_the_probe_is_the_same_whatever_rubyopt
    script = 'p Veragem::Name.probe("date", "my_gem", %w[MyGem])'
    command = [RbConfig.ruby, "-I", File.expand_path("../lib", __dir__), "-rveragem", "-e", script]
    env = Bundler.unbundled_env.merge("RUBYOPT" => "-v")

    assert_equal %(["", "", ""]\n), IO.popen(env, command, unsetenv_others: true, &:read).lines.last
  end

  # the child takes unbundled Ruby's environment alone, without its RUBYOPT, and none of this
  # process's: no RUBYOPT from either
  def test_the_probe_takes_no_rubyopt
    rubyopt = ENV.fetch("RUBYOPT", nil)
    original = Bundler::ORIGINAL_ENV["RUBYOPT"]
    ENV["RUBYOPT"] = Bundler::ORIGINAL_ENV["RUBYOPT"] = "-v"

    assert_equal ["", "", ""], Veragem::Name.probe("date", "my_gem", %w[NoRubyopt])
  ensure
    ENV["RUBYOPT"] = rubyopt
    original ? Bundler::ORIGINAL_ENV["RUBYOPT"] = original : Bundler::ORIGINAL_ENV.delete("RUBYOPT")
  end

  def test_a_failing_probe_refuses
    error = assert_raises(Veragem::Error) { Veragem::Name.probe("set", "my_gem", ["not a constant"]) }

    assert_equal "could not check set's modules", error.message
  end
end
