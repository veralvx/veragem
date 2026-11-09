# frozen_string_literal: true

require "erb"

module Veragem
  # What the templates write as Markdown: a value as text, a badge's image.
  module Markdown
    # What Markdown would read as markup in a text: a character to escape, but an `_` within a word;
    # and a URL's `://` or `www.`, which GFM would link, its escapes shown.
    MARKUP = %r{[\\`*\[\]<~$] | (?<![[:alnum:]])_ | _(?![[:alnum:]]) | &(?=\#?[[:alnum:]]+;) | :(?=//) | (?<=www)\.}x
    private_constant :MARKUP

    # +value+ as Markdown's text, shown as written, as RubyGems shows a summary: its markup escaped,
    # one space between words, as dprint writes them.
    # @param value [String] a value of the gem's, checked
    # @return [String]
    def self.text(value)
      escaped = value.squeeze(" ").gsub(MARKUP) { "\\#{it}" }
      escaped.sub(/\A(?=[#>+-])|\A\d+\K(?=[.)])/) { "\\" }
    end

    # A shields.io static badge's image: its texts' dashes and underscores doubled, as the path
    # takes them, then URL-encoded.
    # @param label [String] the badge's left text
    # @param message [String] its right text
    # @param color [String] the right side's colour, a shields.io name
    # @return [String] the image's URL
    def self.badge(label, message, color)
      label, message = [label, message].map { ERB::Util.url_encode(it.gsub(/[-_]/, "\\0\\0")) }
      "https://img.shields.io/badge/#{label}-#{message}-#{color}"
    end
  end
end
