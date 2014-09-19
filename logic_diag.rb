require 'treetop'

# NOTE: Text must end in a newline character!
text = File.read('test.txt')

Treetop.load 'grammar'

parsed = GrammarParser.new.parse text
p parsed.dump