require 'parslet'
require 'pp'
require 'tree'

text = File.read('test.txt')

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

# Reorder the tree such that the deepest side of each node is the left side
# This is only meaningful for binary operators (OR, AND) that split a node to two children
def reorder_tree(tree)
  reordered = tree
  reordered.each do |n|
    if n.children.count == 2 && n.children[0].node_height < n.children[1].node_height
      r = n.children[0]
      l = n.children[1]
      n.remove_all!
      n << l
      n << r
    end
  end
  return reordered
end

tree = reorder_tree(tree)

tree.print_tree(0, [:content])

# n = node
# f = file
def draw_node(n, drawstates, f)
  # Split blocks into 6x6 subsections of some number of pixels (16 for now)
  # This makes the whole block 96px
  block_size = 6 * 16

  # DEBUG -- draw block surround
  # f.puts %{<rect x="#{d[:x]}" y="#{d[:y]}" width="#{block_size}" height="#{block_size}" stroke="black" fill="transparent"/>}


  # We know at this point where the previous one ENDED...
  # That's what d represents

  d = drawstates[-1]

  # VAR or NOT
  if n.children.count < 2
    
    # Here, we expect only one variable on the stack...
    d = drawstates.pop

    # Lead-in line
    f.puts %{<line x1="#{d[:x]}" y1="#{d[:y]+block_size/2}" x2="#{d[:x]+block_size*1/6}" y2="#{d[:y]+block_size/2}" stroke="black"/>}

    # NOT
    # This will tack onto wherever we previously ended, so no worries here...
    if n.content == "NOT"

      # Not gate is three lines and a circle...
      f.puts %{<line x1="#{d[:x]+block_size*1/6}" y1="#{d[:y]+block_size*1/6}" x2="#{d[:x]+block_size*1/6}" y2="#{d[:y]+block_size*5/6}" stroke="black"/>}
      f.puts %{<line x1="#{d[:x]+block_size*1/6}" y1="#{d[:y]+block_size*1/6}" x2="#{d[:x]+block_size*2/3}" y2="#{d[:y]+block_size/2}" stroke="black"/>}
      f.puts %{<line x1="#{d[:x]+block_size*1/6}" y1="#{d[:y]+block_size*5/6}" x2="#{d[:x]+block_size*2/3}" y2="#{d[:y]+block_size/2}" stroke="black"/>}
      f.puts %{<circle cx="#{d[:x]+block_size*9/12}" cy="#{d[:y]+block_size/2}" r="#{block_size*1/12}" stroke="black" fill="transparent"/>}

    # VAR
    else

      # Text
      f.puts %{<text text-anchor="middle" x="#{d[:x]+block_size/2}" y="#{d[:y]+block_size/2}">#{n.content}</text>}
      
    end
    
    # Follow-on line
    f.puts %{<line x1="#{d[:x]+block_size*5/6}" y1="#{d[:y]+block_size/2}" x2="#{d[:x]+block_size}" y2="#{d[:y]+block_size/2}" stroke="black"/>}

  # AND or OR
  else

  end

  # Mark where we ended...
  drawstates.push({ x: d[:x]+block_size, y: d[:y] })

end

def draw_tree(t, file)
  # Drawstate x and y should always point to top left corner of relevant block
  drawstates = [{ x: 0, y: 0 }]
  t.postordered_each { |n| draw_node(n, drawstates, file) }
end

w = 500;
h = 500;
File.open('testimg.svg', 'w') do |f|
  f.puts %{<svg version="1.1" baseProfile="full" width="#{w}" height="#{h}" xmlns="http://www.w3.org/2000/svg">}
  f.puts %{<rect x="0" y="0" width="#{w}" height="#{h}" fill="white"/>}
  draw_tree(tree, f)
  f.puts %{</svg>}
end
# pp t

# pp forest