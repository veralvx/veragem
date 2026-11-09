# frozen_string_literal: true

module Veragem
  # What the templates write as Markdown: a value as text.
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
  end
end
