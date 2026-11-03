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
    # A magic comment -- an encoding's anywhere, lower-case (Ruby's rule); Ruby's others first (past
    # the ' " : ; it skips) or within -*-, in any case, `-` for `_` (a frozen string literal's after
    # code, a warning: one the tests raise) -- or a RuboCop directive, which would turn its cops off,
    # or fail them.
    MAGIC = /\b(?:en)?coding\s*[:=]|(?:\A['":;\s]*|-\*-.*)(?i:(?:frozen[_-]string[_-]literal|warn[_-]indent|
             shareable[_-]constant[_-]value)\s*:)|(?i:\brubocop\s*:)/x
    # What yard-lint's Markdown and text checks refuse: a list marker (• ·) or a code block's fence
    # first, an em or en dash (.yard-lint.yml's TextSubstitution).
    MARKDOWN = /\A(?:[•·]|```)|[—–]/
    private_constant :TAG, :ANNOTATION, :MAGIC, :MARKDOWN

    # +summary+, refused where it holds a tag, an annotation, a magic comment or Markdown yard-lint
    # refuses, or leaves a backtick or bold open -- a `**` outside code with a non-space beside it, as
    # yard-lint counts (`x ** 2` is no bold).
    # @param summary [String] one line of text, as Project.check passes it
    # @return [String] +summary+
    # @raise [Veragem::Error] the gem's yard-lint or RuboCop would not take it
    def self.check(summary)
      why = refusal(summary)
      raise Error, "invalid summary #{summary.inspect}: #{why}" if why

      summary
    end

    private_class_method def self.refusal(summary)
      return "YARD would read a tag" if summary.match?(TAG)
      return "RuboCop or Ruby would read an annotation or a directive" if annotation?(summary) || summary.match?(MAGIC)
      return "yard-lint would refuse its Markdown" if summary.match?(MARKDOWN)

      "a backtick or ** left open" if left_open?(summary)
    end

    private_class_method def self.left_open?(summary)
      bold = summary.gsub(/`[^`]*`/, "").scan(/(?<=\S)\*\*|\*\*(?=\S)/).size
      summary.count("`").odd? || bold.odd?
    end

    private_class_method def self.annotation?(summary)
      keyword, colon, space = summary.match(ANNOTATION)&.captures
      return false unless keyword && (colon || space)

      !(keyword == keyword.capitalize && !colon)
    end
  end
end
