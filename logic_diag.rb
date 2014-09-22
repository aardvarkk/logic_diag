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

# Parslet
class LogicGrammar < Parslet::Parser
  rule(:ws) {
    match('\\s')
  }

  rule(:newline) {
    match('\\n') 
  }
  
  rule(:identifier) {
    match('[a-zA-Z0-9]').repeat(1).as(:var)
  }
  
  rule(:comment) { 
    ws.repeat >>
    (
      match('#') >>
      match('[^\\n]').repeat 
    ).as(:comment)
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
    identifier.as(:assignee) >>
    ws.repeat >>
    str(':=') >>
    ws.repeat >>
    expr.as(:value)
  }

  rule(:command_detail) {
    assignment | expr
  }

  rule(:command_and_comment) {
    command_detail >> comment
  }

  rule(:command_only) {
    command_detail
  }

  rule(:comment_only) {
    comment
  }

  rule(:command) { 
    identifier.as(:id) >> 
    ws.repeat(1) >>
    (comment_only | command_and_comment | command_only)
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
# parsed = parser.command_only.parse('PSV01 := BFTRIP1')
# parsed = parser.command_and_comment.parse('PSV01 := BFTRIP1 OR BFTRIP2 OR PCT15Q OR PCT14Q OR ASV042 OR M4PT OR 51S1T OR 51S2T OR IN303 OR IN304 #GENERAL TRIP, KEY 3 PH NON-RECLOSEABLE DTT. PCT14Q/PCT15Q ARE O/V PTN,  ASV042 IS OPEN POLE PTN, 51S1T AND 51S2T ARE CH. INDEP. GND O/C, M4PT IS TIME DELAYED CH. INDEP. PTN, IN303 IS 5RX4 PN, IN304 IS 5RX4 ISOL.')
# parsed = parser.command.parse('PROTSEL2  PSV01 := BFTRIP1 OR BFTRIP2 OR PCT15Q OR PCT14Q OR ASV042 OR M4PT OR 51S1T OR 51S2T OR IN303 OR IN304 #GENERAL TRIP, KEY 3 PH NON-RECLOSEABLE DTT. PCT14Q/PCT15Q ARE O/V PTN,  ASV042 IS OPEN POLE PTN, 51S1T AND 51S2T ARE CH. INDEP. GND O/C, M4PT IS TIME DELAYED CH. INDEP. PTN, IN303 IS 5RX4 PN, IN304 IS 5RX4 ISOL.')

begin
  parsed = parser.parse text
rescue Parslet::ParseFailed => error
  puts error.cause.ascii_tree
end
pp parsed