require 'citrus'
require 'treetop'

# NOTE: Text must end in a newline character!
# text = File.read('test.txt')
# Citrus.load 'grammar'
# parsed = Grammar.parse text

# Citrus 
Citrus.load 'calc'
parsed = Calc.parse '0 + +5 * (3 + (8*7)**9)'
p parsed.dump

# Treetop
# Treetop.load 'grammar'
# parsed = GrammarParser.new.parse text
# p parsed