# frozen_string_literal: true

# mutineer's alone (.mutineer.yml's `require:`): it loads each mutant's whole file over lib/'s, so
# every constant there is set again, and Ruby warns of each twice -- thousands of lines a run, of
# no fault. Those two warnings alone are dropped.
quiet = Module.new do
  def warn(message, **)
    redefined = /: warning: (?:already initialized constant \S+|previous definition of [A-Z]\w* was here)$/
    super unless message.match?(redefined)
  end
end
Warning.singleton_class.prepend(quiet)
