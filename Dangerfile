# XXX: Run per dependent?
# XXX: summarize environment? (So that we can run JDK 8/11?)
if !system("./build-dependents.sh '#{Dir.home}/.dependants'")
  warn "It appears that this change breaks a dependent project."
end
