# frozen_string_literal: true

module Veragem
  module Sync
    # What sync does to each harness file, from three object ids: the base (the record's, what
    # veragem last wrote), ours (the gem's file) and theirs (what this veragem writes); nil where
    # there is none. Pure: it reads and writes nothing.
    module Plan
      # A harness file, its ids and its action.
      Row = Data.define(:path, :action, :base, :ours, :theirs)

      # The actions sync takes unasked; the rest it reports, and takes only when selected.
      APPLIED = %i[add update delete merge].freeze

      # The action for a file's ids. +adopt+: there is no record yet, so a file that differs is
      # the gem's own, its theirs recorded as its base.
      # @param base [String, nil]
      # @param ours [String, nil]
      # @param theirs [String, nil]
      # @param adopt [Boolean]
      # @return [Symbol] :same, :add, :conflict, :adopted, :removed, :delete, :orphan, :update,
      #   :keep or :merge
      def self.action(base, ours, theirs, adopt: false)
        return :same if ours == theirs
        return changed(base, ours, theirs) if base
        return :add unless ours

        adopt ? :adopted : :conflict
      end

      # The rows of every path any side has, sorted.
      # @param base [Hash{String => String}] the record's ids
      # @param ours [Hash{String => String}] the gem's
      # @param theirs [Hash{String => String}] this veragem's
      # @param adopt [Boolean]
      # @return [Array<Veragem::Sync::Plan::Row>]
      def self.rows(base, ours, theirs, adopt: false)
        (base.keys | ours.keys | theirs.keys).sort.map do |path|
          Row.new(path, action(base[path], ours[path], theirs[path], adopt:), base[path], ours[path], theirs[path])
        end
      end

      # The record's ids once +applied+ are taken: an applied file's theirs; a file the gem removed,
      # or adopted, theirs too, the gem's file kept as it is; every other its base, so sync reports it
      # again.
      # @param rows [Array<Veragem::Sync::Plan::Row>]
      # @param applied [Array<Veragem::Sync::Plan::Row>] the rows taken
      # @return [Hash{String => String}]
      def self.recorded(rows, applied)
        rows.filter_map do |row|
          id = applied.include?(row) || %i[same removed adopted].include?(row.action) ? row.theirs : row.base
          [row.path, id] if id
        end.to_h
      end

      # A file veragem wrote before: what changed since, and by whom.
      private_class_method def self.changed(base, ours, theirs)
        return :removed unless ours
        return ours == base ? :delete : :orphan unless theirs
        return :update if ours == base

        theirs == base ? :keep : :merge
      end
    end
  end
end
