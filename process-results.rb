#!/usr/bin/env ruby
#SBATCH --job-name=voldemort_conflict_processing
#SBATCH --time=048:00:00
#SBATCH --output=/work/cse990/knorth/outputs/voldemort_conflict_processing.STDOUT
#SBATCH --error=/work/cse990/knorth/outputs/voldemort_conflict_processing.STDERR
#SBATCH --mem-per-cpu=8192
#SBATCH --ntasks=1

class conflict
  attr_accessor :start
  attr_accessor :end

  def initialize
  end
end

def get_commit_parents(commit_hash)
  out = `git show #{commit_hash} --format="%P"`.strip
  parents =  out.split('\n')[0].strip.split(' ')
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
    commit_conflicts = commit_match.captures[1].split(' ')
    commit_parents = get_commit_parents(commit_hash)
    commits_in_topological_order.push commit_hash
    all_commit_conflicts[commit_hash] = commit_conflicts
    all_parents[commit_hash] = commit_parents
  end
end

conflicts = []

for commit_hash in commits_in_topological_order
  commit_parents = all_parents[commit_hash]
  commit_conflicts = all_commit_conflicts[commit_hash]

  parent_conflicts = []
  for parent in commit_conflicts
    parent_conflicts = parent_conflicts | all_commit_conflicts[parent]
  end

  potential_conflict_starts = Array.new(commit_conflicts) #deep copy of array
  potential_conflict_starts.delete_if {|c| parent_conflicts.include? c}

  potential_conflict_ends = Array.new(parent_conflicts)
  potential_conflict_ends.delete_if {|c| commit_conflicts.include? c}

  conflict_starts_to_remove = []
  conflict_ends_to_remove = []
  for potential_conflict_start in potential_conflict_starts
    start_parents = all_parents[potential_conflict_start]
    is_conflict_continued = false
    potential_end_to_remove = nil
    for parent in start_parents
      if potential_conflict_ends.include? parent
        is_conflict_continued = true
        potential_end_to_remove = parent
        break
      end
    end

    if not is_conflict_continued
      next
    end

    # Make sure that the conflict end we're removing wasn't actually merged into
    # the commit we're checking. This would mean that we actually resolved one
    # conflict at the same time as starting another conflict on a parallel
    # branch
    if not commit_parents.include? potential_end_to_remove
      potential_conflict_ends.delete potential_end_to_remove
      potential_conflict_starts.delete potential_conflict_start
    end
  end

  for conflict_end in potential_conflict_ends
    conflicts.find {|c| (c.start.eql? conflict_end) and (c.end == nil)}.end = commit_hash
  end
  for conflict_start in potential_conflict_starts
    new_conflict = Conflict.new
    new_conflict.start = commit_hash
    new_conflict.end = nil
    conflicts.push new_conflict
  end
end