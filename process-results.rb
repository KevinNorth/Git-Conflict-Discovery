#!/usr/bin/env ruby
#SBATCH --job-name=voldemort_conflict_processing
#SBATCH --time=048:00:00
#SBATCH --output=/work/cse990/knorth/outputs/voldemort_conflict_processing.STDOUT
#SBATCH --error=/work/cse990/knorth/outputs/voldemort_conflict_processing.STDERR
#SBATCH --mem-per-cpu=8192
#SBATCH --ntasks=1

class Conflict
  attr_accessor :start
  attr_accessor :end
  attr_accessor :conflicting_commit

  def initialize
  end
end

def get_commit_parents(commit_hash)
  out = `git show #{commit_hash} --format="%P" --no-patch`.strip
  parents =  out.strip.split(' ')
  return parents
end

file = ARGV[0]

graph = File.read(file).split("\n")

Dir.chdir ARGV[1]

commits_in_topological_order = []
all_commit_conflicts = {}
all_parents = {}

commit_regex = /([0-9a-fA-F]+) \| ?([0-9a-fA-F ]*)$/
for row in graph.reverse()
  commit_match = commit_regex.match row
  if commit_match
    commit_hash = commit_match.captures[0]
    commit_conflicts = commit_match.captures[1].split(' ').map {|c| c.strip}
    commit_parents = get_commit_parents(commit_hash)
    commits_in_topological_order.push commit_hash
    all_commit_conflicts[commit_hash] = commit_conflicts
    all_parents[commit_hash] = commit_parents
  end
end

conflicts = []

for commit_hash in commits_in_topological_order
  commit_hash
  commit_parents = all_parents[commit_hash]
  commit_conflicts = all_commit_conflicts[commit_hash] or []

  parent_conflicts = []
  for parent in commit_conflicts
    parent_conflicts = parent_conflicts | all_commit_conflicts[parent]
  end

  new_conflicts = Array.new(commit_conflicts) # deep copy array
  resolved_conflicts = Array.new(parent_conflicts)
  # continued_conflicts = Array.new(parent_conflicts)

  for parent_conflict in parent_conflicts
    if commit_conflicts.include? parent_conflict
      resolved_conflicts.delete parent_conflict
    # else
      # continued_conflicts.delete parent_conflict
    end
  end

  for commit_conflict in commit_conflicts
    if parent_conflicts.include? commit_conflict
      new_conflicts.delete commit_conflict
    end
  end

  for resolved_conflict in resolved_conflicts
    selected_conflicts = conflicts.select {|c| c.conflicting_commit == resolved_conflict}
    for conflict in selected_conflicts
      conflict.end = commit_hash
    end
  end

  for new_conflict in new_conflicts
    conflict = Conflict.new
    conflict.start = commit_hash
    conflict.conflicting_commit = new_conflict
    conflicts.push conflict 
  end
end

for conflict in conflicts
  start_commit = conflict.start
  if start_commit == nil
    start_commit = "nil"
  end
  
  end_commit = conflict.end or "null"
  if end_commit == nil
    end_commit = "nil"
  end

  conflicting_commit = conflict.conflicting_commit
  if conflicting_commit == nil
    conflicting_commit = "nil"
  end

  puts start_commit + ' ' + end_commit + ' | ' + conflicting_commit
end