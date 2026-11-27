# frozen_string_literal: true

require "yaml"

module Veragem
  # .veragem.yml, what `bundle veragem-sync` knows of a gem: the veragem that last wrote its harness
  # (its version, from a release or a checkout), the values the gem was generated with, and the
  # object id of each harness file as that veragem wrote it, which sync tells your changes from
  # veragem's by.
  class Record
    # Its file, in the gem's directory.
    FILE = ".veragem.yml"
    # Where a veragem comes from: RubyGems, or a checkout.
    SOURCES = %w[release path].freeze
    # A git object id, as git writes it: SHA-1's, or SHA-256's.
    ID = /\A[0-9a-f]{40}(?:[0-9a-f]{24})?\z/
    # A path's part: a name, neither . nor .., nor git's own .git as a file system may name it (in
    # any case; NTFS's, with trailing dots or spaces, or GIT~1), in no other directory's syntax
    # (Windows' \ and C:), and no NUL
    PART = /\A(?!\.\.?\z)(?!\.git[. ]*\z)(?!git~\d+\z)[^\\:\0]+\z/i
    # The refusal of a record that is not one.
    INVALID = "invalid #{FILE}: version (a gem's), source (release or path), name, values and files " \
              "(paths in the gem)".freeze
    private_constant :ID, :PART, :INVALID

    # The veragem version that last wrote the harness.
    # @return [String]
    attr_reader :version
    # Where that veragem came from: "release", RubyGems', or "path", a checkout.
    # @return [String]
    attr_reader :source
    # The gem's name.
    # @return [String]
    attr_reader :name
    # The gem's values, as Project.new takes them.
    # @return [Hash{Symbol => String, Boolean, nil}]
    attr_reader :values
    # Each harness file's object id, by its path.
    # @return [Hash{String => String}]
    attr_reader :files

    # Where the veragem at +root+ came from: a checkout has its .git (a worktree's a file), an
    # installed gem none.
    # @param root [String] veragem's directory
    # @return [String] "path" or "release"
    def self.source_of(root) = File.exist?(File.join(root, ".git")) ? "path" : "release"

    # +project+'s values, as Project.new takes them again: nil for none, keywords joined by ", ".
    # @param project [Veragem::Project]
    # @return [Hash{Symbol => String, Boolean, nil}]
    def self.values_of(project)
      { author: project.author, email: project.email, github: project.github, summary: project.summary,
        license: project.license, exe: project.exe?, citation: project.citation?, badges: project.badges?,
        given_names: project.given_names, family_names: project.family_names, alias: project.alias_name,
        orcid: project.orcid, keywords: project.keywords&.join(", ") }
    end

    # The record of +project+'s gem, just generated into +target+ by this veragem: each harness
    # file of +entries+ as git hashes it there, as its index holds it.
    # @param project [Veragem::Project] the gem
    # @param target [String] its directory, its files added
    # @param entries [Array<Veragem::Generator::Entry>] its files
    # @return [Veragem::Record]
    # @raise [Veragem::Error] git failed
    def self.of(project, target, entries)
      paths = entries.select(&:harness).map(&:path)
      new(version: VERSION, source: source_of(File.dirname(Generator::TEMPLATE)), name: project.name,
          values: values_of(project), files: Git.ids(target, paths))
    end

    # The record in +dir+.
    # @param dir [String] a gem's directory
    # @return [Veragem::Record]
    # @raise [Veragem::Error] it has none, or one that is not a record
    def self.read(dir)
      path = File.join(dir, FILE)
      raise Error, "no #{FILE} in #{dir}: a gem veragem generated has one" unless File.file?(path)

      parse(YAML.safe_load(File.read(path, encoding: Encoding::UTF_8), symbolize_names: true))
    rescue Psych::Exception => e
      raise Error, "invalid #{FILE}: #{e}"
    end

    # @param version [String] the veragem version that wrote the harness
    # @param source [String] "release" or "path"
    # @param name [String] the name the gem was generated with
    # @param values [Hash{Symbol => String, Boolean, nil}] as Project.new takes them
    # @param files [Hash{String => String}] each harness file's object id
    # @return [void]
    def initialize(version:, source:, name:, values:, files:)
      @version = version
      @source = source
      @name = name
      @values = values
      @files = files
    end

    # The gem it records.
    # @return [Veragem::Project]
    # @raise [Veragem::Error] a value is refused
    def project
      given = values #: Project::values
      # rubocop:disable-next Lint/NameTypo -- the project index lacks Class#new, and takes Project#nest for it
      Project.new(name, given)
    end

    # Writes it into +dir+.
    # @param dir [String] the gem's directory
    # @return [void]
    def write(dir)
      data = { version:, source:, name:, values: values.transform_keys(&:to_s), files: }.transform_keys(&:to_s)
      File.binwrite(File.join(dir, FILE), "# bundle veragem-sync reads this file, and rewrites it\n#{YAML.dump(data)}")
    end

    # each value a string, a boolean or none; each file's a path in the gem, its id a git object's
    private_class_method def self.valid?(values, files)
      values.values.all? { it in String | true | false | nil } && files.all? do |path, id|
        parts = path.to_s.split("/", -1)
        !parts.empty? && parts.all? { PART.match?(it) } && case id when String then ID.match?(id) end
      end
    end

    # A record of the YAML's data, every field of its kind.
    private_class_method def self.parse(data)
      # checked in the body, not in a guard: coverage sees no line of a pattern run, nor mutineer its mutants
      case data
      in { version: String => version, source: String => source, name: String => name, values: Hash => values,
           files: Hash => files }
        raise Error, INVALID unless Gem::Version.correct?(version) && SOURCES.include?(source) && valid?(values, files)

        new(version:, source:, name:, values:, files: files.transform_keys(&:to_s))
      else
        raise Error, INVALID
      end
    end
  end
end
