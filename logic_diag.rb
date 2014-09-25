require 'parslet'
require 'pp'
require 'tree'

text = File.read('test.txt')

def create_vartable(parsed)
  vartable = []
  def get_vars(obj)
    return [] if obj.nil? || !obj.is_a?(Hash)
    vartable = []
    # Grab ourselves if we have a var at our level
    vartable << obj[:var].to_s if obj.key?(:var)
    # Go into our children if we have any
    obj.each { |k,v| vartable += get_vars v }
    vartable
  end
  parsed.each do |h|
    vartable += get_vars h
  end
  vartable.uniq!
  vartable.sort! unless vartable.nil?
end

# Parslet
class LogicGrammar < Parslet::Parser
  rule(:ws) {
    # DO NOT use \s for a space -- it seemingly includes newlines!
    str(' ')
  }

  rule(:newline) {
    match('\n') 
  }
  
  rule(:alphanum) {
    match('[a-zA-Z0-9]').repeat(1)
  }

  rule(:identifier) {
    alphanum.as(:var)
  }
  
  rule(:comment) { 
    (
      str('#') >>
      match('[^\n]').repeat 
    )#.as(:comment)
  }

  rule(:group_expr) {
    (
      str('(') >>
      expr >>
      str(')')
    #).as(:group) |
    ) |
    identifier
  }

  rule(:not_expr) {
    (
      str('NOT') >>
      ws.repeat(1) >>
      group_expr
    ).as(:not) | 
    group_expr
  }

  rule(:and_expr) { 
    (
      not_expr.as(:left) >> 
      ws.repeat(1) >>
      str('AND') >> 
      ws.repeat(1) >>
      and_expr.as(:right)
    ).as(:and) | 
    not_expr
  }

  rule(:or_expr) {
    (
      and_expr.as(:left) >> 
      ws.repeat(1) >>
      str('OR') >> 
      ws.repeat(1) >>
      or_expr.as(:right)
    ).as(:or) | 
    and_expr
  }

  rule(:expr) {
    ws.repeat >>
    or_expr >>
    ws.repeat
  }

  rule(:assignment) {
    identifier >>
    ws.repeat >>
    str(':=') >>
    ws.repeat >>
    expr.as(:val)
  }

  rule(:command_detail) {
    assignment | expr
  }

  rule(:command) { 
    identifier >> 
    ws.repeat(1) >>
    command_detail.maybe.as(:val) >>
    comment.maybe
  }

  rule(:commandset) { 
    (command >> (newline | any.absent?)).repeat
  }

  root(:commandset)
end

parser = LogicGrammar.new

# TESTS!
  # parsed = parser.identifier.parse('abc123')
  # parsed = parser.expr.parse('  abc123 ')
  # parsed = parser.group_expr.parse('( abc123 )')
  # parsed = parser.or_expr.parse('a OR b')
  # parsed = parser.or_expr.parse('a OR b AND c')
  # parsed = parser.or_expr.parse('a AND b')
  # parsed = parser.and_expr.parse('(a AND b)')
  # parsed = parser.expr.parse('(a OR b) AND c')
  # parsed = parser.group_expr.parse('(a OR b)')
  # parsed = parser.not_expr.parse('NOT a')
  # parsed = parser.not_expr.parse('NOT (a)')
  # parsed = parser.expr.parse('a OR b')
  # parsed = parser.expr.parse('NOT a OR b')
  # parsed = parser.expr.parse('NOT (a OR b)')
  # parsed = parser.expr.parse('BFTRIP1 OR BFTRIP2 OR PCT15Q OR PCT14Q OR ASV042 OR M4PT OR 51S1T OR 51S2T OR IN303 OR IN304 ')
  # parsed = parser.expr.parse('IN204 AND (M1P OR M2P AND COMPRM) OR IN206 AND 3PT OR IN207 AND NOT SPO AND SPLSHT AND 3PT ')
  # parsed = parser.expr.parse('PSV01 OR RMB6A ')
  # parsed = parser.expr.parse('NOT (SPO OR SPT)')
  # parsed = parser.assignment.parse('PSV63 := NOT (SPO OR SPT)')
  # parsed = parser.command.parse('PROTSEL1  # <<<<<<< LINE INTENTIONALLY LEFT BLANK >>>>>>>')
  # parsed = parser.command.parse('PROTSEL2 PSV01 := BFTRIP1')
  # parsed = parser.command_detail.parse('PSV01 := BFTRIP1')
  # parsed = parser.command.parse('PROTSEL2  PSV01 := BFTRIP1 OR BFTRIP2 OR PCT15Q OR PCT14Q OR ASV042 OR M4PT OR 51S1T OR 51S2T OR IN303 OR IN304 #GENERAL TRIP, KEY 3 PH NON-RECLOSEABLE DTT. PCT14Q/PCT15Q ARE O/V PTN,  ASV042 IS OPEN POLE PTN, 51S1T AND 51S2T ARE CH. INDEP. GND O/C, M4PT IS TIME DELAYED CH. INDEP. PTN, IN303 IS 5RX4 PN, IN304 IS 5RX4 ISOL.')
  # parsed = parser.command.parse('OUT301  TPA1 OR ASV051 OR RTA1 OR PCT01Q OR PLT09 # TRIP 5CB4 PHASE A')
  # parsed = parser.command.parse('TMB1A IN308 AND PSV53 OR RB01 #PT KEY OUT. KEY INCLUDES ALL TERM OF TRCOMM EQ. 3PT IS 3 PHASE TRIP, 67 Q2 FOR ADDITIONAL KEY SENSITIVITY')
  # parsed = parser.command.parse('PROTSEL5  PSV63 := NOT (SPO OR SPT)')

begin
  forest = parser.parse text
rescue Parslet::ParseFailed => error
  puts error.cause.ascii_tree
end
# pp forest

# Create a variable table
vartable = create_vartable forest
# pp vartable

# Create a variable table per-tree (to potentially find overlap)
# forest.each { |t| pp create_vartable [t] }

# To be a leaf node, we must have only one key-pair value of :var => "varname"
def find_leaf_var(tree, var)
  return nil if !tree.is_a?(Hash)

  # Try our children first...
  tree.each do |k,v|
    leaf_instance = find_leaf_var(v, var)
    return leaf_instance if leaf_instance
  end

  # Now examine ourselves...
  if tree.key?(:var) && tree[:var] == var && tree.keys.count == 1
    return tree
  else
    return nil
  end
end

# To be a parent node, we must have one key-pair value of :var => "varname" as well as additional keys
def find_parent_var(tree, var)
  return nil if !tree.is_a?(Hash)

  # Try our children first...
  tree.each do |k,v|
    parent_instance = find_parent_var(v, var)
    return parent_instance if parent_instance
  end

  # Now examine ourselves...
  if tree.key?(:var) && tree[:var] == var && tree[:val].is_a?(Hash)
    return tree
  else
    return nil
  end
end

# To be settled, the forest must NOT contain a matching pair such that one is a leaf node and the other has children
def settled(forest, vartable)
  # Go through each variable in the vartable and see if we're able to find it both in a leaf and in a place that has children
  vartable.each do |v|
    # pp v

    # Go through every tree in the forest to see if we find a matching pair
    leaf_instance = nil
    parent_instance = nil    
    forest.each do |t|
      leaf_instance   ||= find_leaf_var(t, v)
      parent_instance ||= find_parent_var(t, v)
      return {leaf: leaf_instance, parent: parent_instance} if leaf_instance && parent_instance
    end
  end

  return nil
end

# def remove_subtree(tree, to_remove)
#   return if !tree.is_a?(Hash)
  
#   # Remove from our children first
#   tree.each { |k,v| remove_subtree(v, to_remove) }

#   # If our value matches the thing to remove, do it
#   if tree.has_key?(:val) && tree[:val] == to_remove
#     tree[:val] = to_remove[:var]
#   end
# end

def replace_leaf_with_subtree(tree, leaf, subtree)
  return if !tree.is_a?(Hash)

  # Work on our children
  tree.each { |k,v| replace_leaf_with_subtree(v, leaf, subtree) }

  # Work on ourselves
  if tree == leaf
    tree.replace subtree
  end
end

while lp = settled(forest, vartable)
  
  # puts "--- FOREST BEFORE"
  # pp forest

  # puts "--- LEAF"
  # pp lp[:leaf]
  # puts "--- PARENT"
  # pp lp[:parent]

  # First, get rid of the parent entry from the original trees (delete it)
  # This works because we have a copy
  # forest.each do |t|
  #   remove_subtree(t, lp[:parent])
  # end

  # Then, replace all leaf entries of this variable with parent entries of this variable
  forest.each do |t|
    replace_leaf_with_subtree(t, lp[:leaf], lp[:parent])
  end

  # puts "--- FOREST AFTER"
  # pp forest

end

# pp forest.last

# Create the RubyTree from a parsed hash
def append_to_tree(hash, idx)
  # return nil if !hash.is_a?(Hash)

  if hash.key? :var
    node = Tree::TreeNode.new(idx.to_s, hash[:var].to_s)
    idx += 1
    node << append_to_tree(hash[:val], idx) if hash[:val]
  elsif hash.key? :or
    node = Tree::TreeNode.new(idx.to_s, "OR")
    idx += 1
    node << append_to_tree(hash[:or][:left], idx)
    idx += node.size - 1
    node << append_to_tree(hash[:or][:right], idx)
  elsif hash.key? :and
    node = Tree::TreeNode.new(idx.to_s, "AND")
    idx += 1
    node << append_to_tree(hash[:and][:left], idx)
    idx += node.size - 1
    node << append_to_tree(hash[:and][:right], idx)
  elsif hash.key? :not
    node = Tree::TreeNode.new(idx.to_s, "NOT")
    idx += 1
    node << append_to_tree(hash[:not], idx)
  else
    throw "Shouldn't be here..."
  end

  return node
end
tree = append_to_tree(forest[2], 0)

# To get this method to work, change RubyTree like this:
# def print_tree(level = 0, to_print = [:name])
#   if is_root?
#     print "*"
#   else
#     #print "|" unless parent.is_last_sibling?
#     print(' ' * (level - 1) * 4)
#     print(is_last_sibling? ? "+" : "|")
#     print "---"
#     print(has_children? ? "+" : ">")
#   end

#   str = ""
#   str += " #{name}" if to_print.include? :name
#   str += " #{content}" if to_print.include? :content
#   puts str

#   children { |child| child.print_tree(level + 1, to_print) if child } # Child might be 'nil'
# end
tree.print_tree(0, [:content])

# pp forest.last

def get_deepest(t, depth)
  return depth-1 if !t.is_a?(Hash)
  deepest_child = depth
  t.each { |k,v| deepest_child = [deepest_child, get_deepest(v, depth+1)].max }
  return deepest_child
end

def draw_node(n, file)
  return if !n.is_a?(Hash)

  # Leaves of the tree are the inputs, so process children first
  # Children should be contained within any non-var keys
  n.each { |k,v| draw_node(v, file) if k != :var }

  # This is a variable
  if n.key? :var
    # puts "Var #{n[:var]}"
  else

  end
end

def draw_tree(t, file)
  # puts get_deepest(t, 0)
  draw_node(t, file)
end

t = forest.last
w = 500;
h = 500;
File.open('testimg.svg', 'w') do |f|
  f.puts %{<svg version="1.1" baseProfile="full" width="#{w}" height="#{h}" xmlns="http://www.w3.org/2000/svg">}
  f.puts %{<rect x="0" y="0" width="#{w}" height="#{h}" fill="white"/>}
  draw_tree(t, f)
  f.puts %{</svg>}
end
# pp t

# pp forest