require 'awesome_print'
require 'citrus'
require 'parslet'
require 'pp'
require 'treetop'

text = File.read('test.txt')

# # NOTE: Text must end in a newline character!
# Citrus.load 'grammar'
# parsed = Grammar.parse text

# Citrus 
# Citrus.load 'calc'
# parsed = Calc.parse '(-0  + +5) * (3 + (8*7)**9) / 50 + 3'
# parsed = Calc.parse '5*4*3'

# p parsed.dump

# Treetop
# Treetop.load 'grammar'
# parsed = GrammarParser.new.parse text
# p parsed

# x1 = x coord of top input terminal
# y1 = y coord of of top input terminal
# y2 = y coord of bottom input terminal
# x2 = x coord of output terminal
# return an SVG string corresponding to an OR gate at the given location
def or_gate(x1,y1,y2,x2)
  d = y2 - y1
  h = 2 * d
  %{<line x1="#{x1}" x2="#{x1}" y1="#{y1-d}" y2="#{y2+d}" stroke="black"/>}
end

def make_svg(filename)
  # Calculate total required dimensions before making the SVG
  w = 500
  h = 500
  File.open(filename, 'w') do |f|
    f.puts %{<svg version="1.1" baseProfile="full" width="#{w}" height="#{h}" xmlns="http://www.w3.org/2000/svg">}
    f.puts %{<rect x="0" y="0" width="#{w}" height="#{h}" fill="white"/>}
    f.puts or_gate(50,50,100,100)
    f.puts %{</svg>}
  end
end

# class TestGrammar < Parslet::Parser
#   rule(:newline) {
#     match('\n')
#   }
#   rule(:foo) {
#     str('foo') >> newline
#   }
#   root(:foo)
# end

# pp TestGrammar.new.parse text

# Parslet
class LogicGrammar < Parslet::Parser
  rule(:ws) {
    # DO NOT use \s for a space -- it seemingly includes newlines!
    str(' ')
  }

  rule(:newline) {
    match('\n') 
  }
  
  rule(:identifier) {
    match('[a-zA-Z0-9]').repeat(1).as(:var)
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
    ).as(:group) |
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
    (command >> newline).repeat
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
  parsed = parser.parse text
rescue Parslet::ParseFailed => error
  puts error.cause.ascii_tree
end
# pp parsed

# Create a variable table
vartable = []
def get_vars(hash)

end
parsed.each do |h|
  vartable << get_vars(h)
end


# make_svg('testimg.svg')
