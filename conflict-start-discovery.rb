#!/usr/bin/env ruby

class Branch
  attr_reader :current_head

  def initialize(commit)
    @current_head = commit
  end

  def update_head(commit)
    @current_head = commit
  end
end

class Branches
  def initialize
    @branches = []
  end

  def advance(commit, parents)
    matching_branches = []
    for branch in @branches
      if parents.include? (branch.current_head)
        matching_branches.push branch
      end
    end

    if matching_branches.count == 0
      @branches.push Branch.new(commit)
    elsif matching_branches.count == 1
      matching_branches[0].update_head(commit)
    else
      for matching_branch in matching_branches
        @branches.delete_if {|b| b.current_head.eql? (matching_branch.current_head)}
      end
      @branches.push Branch.new(commit)
    end
  end

  def get_current_heads
    return @branches.map {|b| b.current_head}
  end

  def get_current_heads_except(commit)
    current_heads = get_current_heads()
    current_heads.delete(commit)
    return current_heads
  end
end

def get_commit_parents(commit_hash)
  return `git show #{commit_hash} --format="%P" --no-patch`.strip.split(' ')
end

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

working_dir = ARGV[0]

if working_dir != nil
  Dir.chdir working_dir
end

graph = nil
if ARGV[1]
  graph = `git log --format="%H" --graph --no-color --author-date-order`.split("\n").reverse
else
  graph = `git log --format="%H" --graph --no-color --author-date-order --since=#{ARGV[1]}`.split("\n").reverse
end

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

for row in updated_graph.reverse
  puts row
end