# frozen_string_literal: true

# Coverage first, before lib/ loads: every line, branch and method of it, a file the tests never
# load included (`cover`). But version.rb: the gemspec requires it, as Bundler reads the gemspec
# before any test runs -- a constant alone.
require "simplecov"
SimpleCov.start "strict" do
  cover "lib/**/*.rb"
  skip "lib/veragem/version.rb"
end

require "veragem"

require "minitest/autorun"
require "pbt"
require "json"
require "tmpdir"

module Veragem
  # What the tests share: a project's values, and a directory to generate into.
  module TestSupport
    VALUES = { author: "Jane Doe", github: "jane", summary: "A Ruby gem.", license: "dual" }.freeze

    def project(name = "my_gem", **values) = Project.new(name, VALUES.merge(values))

    def in_tmpdir(&) = Dir.mktmpdir("veragem-test", &)

    def with_env(values)
      saved = ENV.to_h
      ENV.update(values)
      yield
    ensure
      ENV.replace(saved)
    end
  end

  # What the generator's tests share: each kind generated, and what it holds.
  module GeneratedSupport
    # Each kind and license, generated: its project, its directory and its files.
    def each_kind
      [["my_gem", false, "dual"], ["my-tool", true, "mit"], ["my_lib", false, "apache"]].each do |name, exe, license|
        in_tmpdir do |dir|
          gem = project(name, exe:, license:, email: "jane@example.com")
          target = File.join(dir, name)
          Veragem::Generator.generate(gem, target)
          yield gem, target, files_in(target)
        end
      end
    end

    def files_in(target)
      Dir.glob("**/*", File::FNM_DOTMATCH, base: target).reject do |file|
        file.start_with?(".git/") || File.directory?(File.join(target, file))
      end
    end

    def read(target, file) = File.read(File.join(target, file), encoding: Encoding::UTF_8)

    # The gemspec's fields, read in a process of its own: loading it defines the gem's module.
    def spec_of(target, gem)
      script = "spec = Gem::Specification.load(ARGV[0]); " \
               "print JSON.dump(%w[name version authors email licenses homepage executables files summary]" \
               ".to_h { [it, spec.public_send(it).then { |v| v.is_a?(Gem::Version) ? v.to_s : v }] })"
      JSON.parse(IO.popen([RbConfig.ruby, "-rjson", "-e", script, "#{gem.name}.gemspec"],
                          chdir: target, external_encoding: Encoding::UTF_8, &:read))
    end
  end
end
