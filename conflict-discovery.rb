#!/usr/bin/env ruby

# Represents a branch that is being walked in a Git repository
# Used to keep track of parallel branches in order to attempt
# merges across different branches. Also keeps track of the most
# recent commit visited in the branch as the repository is walked.
class Branch
  attr_reader :current_head

  def initialize(commit)
    @current_head = commit
  end

  def update_head(commit)
    @current_head = commit
  end
end

# A list of parallel branches in a Git repository
# This class is used to take care of a lot of the
# logic involved in keeping track of the parallel
# branches and automatically removing and adding
# branches from the list.
class Branches
  def initialize
    @branches = []
  end

  # Updates the list of branches based on the next commit in the
  # repository. Also automatically removes branches from the list
  # as they're merged and adds branches to the list when they're
  # created.
  #
  # Inputs:
  # commit: The SHA1 hash of the next commit encountered while
  #         walking the repository.
  # parents: A list of SHA1 hashes for the commits that are the
  #         parents of the commit passed in as the other argument 
  def advance(commit, parents)
    matching_branches = []
    for branch in @branches
      if parents.include?(branch.current_head)
        matching_branches.push branch
      end
    end

    if matching_branches.count == 0
      @branches.push Branch.new(commit)
    elsif matching_branches.count == 1
      matching_branches[0].update_head(commit)
    else
      for matching_branch in matching_branches
        @branches.delete_if {|b| b.current_head.eql?(matching_branch.current_head)}
      end
      @branches.push Branch.new(commit)
    end
  end

  # Returns a list of the SHA1 hashes for the most recently
  # visited commits in each branch
  def get_current_heads
    return @branches.map {|b| b.current_head}
  end

  # Returns a list of the SHA1 hashes for the most recently
  # visited commits in each branch, omitting the commit
  # passed in as an argument
  #
  # Input:
  # commit: The SHA1 hash of the commit to omit
  def get_current_heads_except(commit)
    current_heads = get_current_heads()
    current_heads.delete(commit)
    return current_heads
  end
end

class Conflict
  attr_accessor :start
  attr_accessor :end
  attr_accessor :conflicting_commit

  def initialize
  end
end

# Gets a list of SHA1 hashes for the commits that are the
# parents of the specified commit.
#
# Input:
# commit: The SHA1 hash of the commit for which you want to
#         find parents
def get_commit_parents(commit_hash)
  out = `git show #{commit_hash} --format="%P" --no-patch`.strip
  parents =  out.strip.split(' ')
  return parents
end


# Determines whether or not two commits conflict with
# each other by attempting to merge them.
#
# Input:
# commit1: The SHA1 hash of one of the commits to try merging
# commit2: The SHA1 hash of the other commit to try merging
def do_commits_conflict?(commit1, commit2)
  result = false

  `git checkout #{commit1}`
  merge_output = `git merge #{commit2}`

  if /CONFLICT/ =~ merge_output
    result = true
    `git merge --abort`
  end

  `git clean -xdf`
  `git reset --hard`
  `git checkout .`

  return result
end

Dir.chdir ARGV[0]

graph = `git log --format="%H" --graph --no-color --date-order`.split("\n").reverse

branches = Branches.new
updated_graph = []
commit_regex = /([0-9a-fA-F]+)$/
for row in graph
  commit_match = commit_regex.match row
  if commit_match
    commit_hash = commit_match.captures[0]
    commit_parents = get_commit_parents(commit_hash)
    branches.advance(commit_hash, commit_parents)

    other_commits = branches.get_current_heads_except(commit_hash)
    conflicting_commits = []
    for other_commit in other_commits
      if do_commits_conflict?(commit_hash, other_commit)
        conflicting_commits.push other_commit
      end
    end
    new_row = "#{row} | #{conflicting_commits.join(' ')}"
    updated_graph.push(new_row)
  else
    updated_graph.push row
  end
end

for row in updated_graph.reverse()
    puts row
end

commits_in_topological_order = []
all_commit_conflicts = {}
all_parents = {}

commit_regex = /([0-9a-fA-F]+) \| ?([0-9a-fA-F ]*)$/
for row in updated_graph
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
  for parent in commit_parents
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

  puts start_commit + ' ' + end_commit
end