# frozen_string_literal: true

# Steep checks lib/ against sig/, its strictest diagnostics on: `rake steep`.
D = Steep::Diagnostic

target :lib do
  signature "sig"
  check "lib"
  library "erb", "fileutils", "optparse"
  configure_code_diagnostics(D::Ruby.strict)
end
