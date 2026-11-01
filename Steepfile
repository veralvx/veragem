# frozen_string_literal: true

# Steep checks lib/ against sig/, its strictest diagnostics on: `rake steep`.
target :lib do
  signature "sig"
  check "lib"
  library "erb", "fileutils", "json", "open3", "optparse", "tmpdir"
  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict)
end
