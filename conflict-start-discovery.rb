#!/usr/bin/env ruby

working_dir = ARGV[0]
Dir.chdir working_dir

graph = `git log --format="%H" --graph --no-color --author-date-order`.split("\n")

puts graph.reverse