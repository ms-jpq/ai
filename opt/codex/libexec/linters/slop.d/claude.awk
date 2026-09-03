BEGIN {
  pattern("\302\267", "no decorative Unicode dots")
  pattern("\342\200\224", "no em-dashes")
  pattern("\342\200\242", "use Markdown list markers")
  pattern("\342\210\231", "no decorative Unicode dots")
}
