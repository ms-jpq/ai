BEGIN {
  pattern("\342\200\224", "no em-dashes")
  pattern("earns? (their|its) (place|keep)")
  pattern("genuine(ly)?|truly")
  pattern("load[- ]bearing")
  pattern("meaningful(ly)?")
  pattern("that'?s the")
  pattern("the whole (game|point|thing|idea|reason|purpose|premise|exercise|trick)")
}
