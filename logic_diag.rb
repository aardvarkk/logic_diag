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
    match('\\s').repeat(1) 
  }

  rule(:newline) {
    match('\\n') 
  }
  
  rule(:identifier) {
    match('[a-zA-Z0-9]').repeat(1)
  }
  
  rule(:comment_to_eol) { 
    match('#') >> match('[^#\\n]').repeat 
  }

  rule(:command_detail) {
    match('[^#\\n]').repeat(1) 
  }

  rule(:command) { 
    identifier.as(:name) >> ws.repeat(1) >> command_detail.as(:detail).repeat >> comment_to_eol.as(:comment).repeat >> newline
  }

  rule(:commandset) { 
    command.as(:cmd).repeat(1) 
  }

  root(:commandset)
end

begin
  parsed = LogicGrammar.new.parse text
rescue Parslet::ParseFailed => error
  puts error.cause.ascii_tree
end
pp parsed