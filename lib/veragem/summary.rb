# frozen_string_literal: true

module Veragem
  # The gem's summary, which is its module's comment too: one the gem's own yard-lint and RuboCop take
  # as its documentation.
  module Summary
    # What YARD reads as a tag first in a comment: its own (`@param`, `(see`), and those yard-lint
    # (.yard-lint.yml) takes for one written informally.
    TAG = /\A(?:@|\(see\b|(?:note|important|todo|fixme|see(?:\ also)?|warning|deprecated|author|version|since
            |returns|raises|example):)/xi
    # A RuboCop annotation, no documentation, as its AnnotationComment reads one: a keyword first, then
    # a colon, spaces before it or not, or a space -- but a sentence's capitalized first word, a word
    # after it (a summary, stripped, has one after a space).
    ANNOTATION = /\A(todo|fixme|optimize|hack|review|note)\b(\s*:)?(\s+)?/i
    # A magic comment as RuboCop reads one -- an encoding's anywhere, lower-case (Ruby's rule), a
    # frozen string literal's first, in any case -- or a RuboCop directive, which would turn its cops
    # off, or fail them.
    MAGIC = /\b(?:en)?coding\s*[:=]|\A(?i:frozen[_-]string[_-]literal):|(?i:\brubocop\s*:)/
    private_constant :TAG, :ANNOTATION, :MAGIC

    # +summary+, refused where it holds a tag, an annotation or a magic comment, or leaves a backtick
    # or bold open -- a `**` outside code with a non-space beside it, as yard-lint counts (`x ** 2` is
    # no bold).
    # @param summary [String] one line of text, as Project.check passes it
    # @return [String] +summary+
    # @raise [Veragem::Error] the gem's yard-lint or RuboCop would not take it
    def self.check(summary)
      raise Error, "invalid summary #{summary.inspect}: YARD would read a tag" if summary.match?(TAG)

      misread = annotation?(summary) || summary.match?(MAGIC)
      raise Error, "invalid summary #{summary.inspect}: RuboCop would read an annotation or a directive" if misread

      bold = summary.gsub(/`[^`]*`/, "").scan(/(?<=\S)\*\*|\*\*(?=\S)/).size
      left_open = summary.count("`").odd? || bold.odd?
      raise Error, "invalid summary #{summary.inspect}: a backtick or ** left open" if left_open

      summary
    end

    private_class_method def self.annotation?(summary)
      keyword, colon, space = summary.match(ANNOTATION)&.captures
      return false unless keyword && (colon || space)

      !(keyword == keyword.capitalize && !colon)
    end
  end
end
