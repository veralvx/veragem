# frozen_string_literal: true

require "test_helper"
require "prism"
require "yaml"

class TestGenerator < Minitest::Test
  include Veragem::TestSupport
  include Veragem::GeneratedSupport

  EXECUTABLES = %w[bin/console bin/setup .githooks/commit-msg .githooks/pre-commit .githooks/pre-push
                   .github/release-notes.sh].freeze
  RUBY = %r{\.(rb|gemspec)\z|\A(Gemfile|Rakefile|Steepfile|bin/console|bin/setup|exe/.*)\z}

  def test_a_gem_has_its_files
    each_kind do |gem, _, files|
      expected = %W[#{gem.name}.gemspec lib/#{gem.path}.rb lib/#{gem.path}/version.rb sig/#{gem.path}.rbs
                    test/test_#{gem.underscored}.rb Rakefile Gemfile Steepfile flake.nix flake.lock README.md]

      assert_empty expected - files
    end
  end

  def test_a_command_line_is_the_exe_kinds_alone
    each_kind do |gem, _, files|
      cli = %W[exe/#{gem.name} lib/#{gem.path}/cli.rb test/test_cli.rb .github/workflows/image.yml
               .github/image-registries.sh]

      assert_equal gem.exe ? cli.sort : [], (files & cli).sort
    end
  end

  # a module of the gem's named OptionParser, which the command line's lookup would find first
  def test_the_command_line_names_option_parser_from_the_top_alone_where_the_gem_has_one
    cli = File.join(Veragem::Generator::TEMPLATE, "lib/%path%/cli.rb.erb")
    { "my-tool" => " OptionParser", "my-option_parser" => " ::OptionParser" }.each do |name, constant|
      code = Veragem::Generator.render(cli, project(name, exe: true))

      assert_includes code, "rescue#{constant}::ParseError"
      assert_includes code, "#{constant}.new"
    end
  end

  def test_the_licenses_are_the_ones_chosen
    each_kind do |gem, _, files|
      licenses = { "MIT" => "LICENSE-MIT", "Apache-2.0" => "LICENSE-APACHE" }.values_at(*gem.licenses)

      assert_equal licenses.sort, files.grep(/\ALICENSE/).sort
    end
  end

  def test_nothing_is_left_unrendered
    each_kind do |_, target, files|
      assert_empty files.grep(/%(name|path|underscored)%|\.erb\z/)
      assert_empty(files.select { read(target, it).match?(/<%|%>/) })
    end
  end

  def test_the_executables_keep_their_mode
    each_kind do |gem, target, files|
      executables = EXECUTABLES + (gem.exe ? ["exe/#{gem.name}", ".github/image-registries.sh"] : [])

      assert_equal executables.sort, files.select { File.executable?(File.join(target, it)) }.sort
    end
  end

  def test_the_ruby_parses
    each_kind do |_, target, files|
      assert_empty(files.grep(RUBY).reject { Prism.parse_file(File.join(target, it)).success? })
    end
  end

  def test_the_yaml_and_the_lock_parse
    each_kind do |_, target, files|
      files.grep(/\.ya?ml\z/).each { YAML.load_file(File.join(target, it)) }

      assert_equal %w[nixpkgs root], JSON.parse(read(target, "flake.lock"))["nodes"].keys.sort
    end
  end

  def test_the_gemspec_is_the_projects
    each_kind do |gem, target, _|
      assert_equal [gem.name, "0.1.0", ["Jane Doe"], ["jane@example.com"], gem.licenses, gem.exe ? [gem.name] : []],
                   spec_of(target, gem).values_at(*%w[name version authors email licenses executables])
    end
  end

  def test_the_gem_ships_its_code_and_signatures_alone
    each_kind do |gem, target, _|
      shipped = spec_of(target, gem)["files"]

      assert_includes shipped, "sig/#{gem.path}.rbs"
      assert_empty shipped.grep_v(%r{\A(lib|sig|exe)/|\A(README\.md|LICENSE-MIT|LICENSE-APACHE)\z})
    end
  end

  def test_the_values_are_written_as_given
    in_tmpdir do |dir|
      gem = project(author: "José \"Q\" \#{x}", summary: "Greets \\ people.")
      Veragem::Generator.generate(gem, File.join(dir, "my_gem"))

      assert_equal [["José \"Q\" \#{x}"], "Greets \\ people."],
                   spec_of(File.join(dir, "my_gem"), gem).values_at("authors", "summary")
      assert_match(/\ACopyright #{Time.now.year} José "Q" \#\{x\}$/, read(dir, "my_gem/LICENSE-MIT"))
    end
  end

  def test_it_is_a_git_repository_on_main_its_files_added
    each_kind do |_, target, files|
      assert_equal "main", IO.popen(%w[git symbolic-ref --short HEAD], chdir: target, &:read).strip
      assert_equal files.sort, IO.popen(%w[git ls-files], chdir: target, &:read).lines(chomp: true).sort
    end
  end

  def test_the_modes_follow_the_umask
    in_tmpdir do |dir|
      umask = File.umask(0o077)
      begin
        Veragem::Generator.generate(project, File.join(dir, "my_gem"))
      ensure
        File.umask(umask)
      end

      assert_equal([0o600, 0o700], %w[README.md bin/setup].map { File.stat(File.join(dir, "my_gem", it)).mode & 0o777 })
    end
  end
end
