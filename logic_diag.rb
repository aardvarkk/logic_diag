require 'citrus'

# NOTE: Text must end in a newline character!
text = File.read('test.txt')

Citrus.load 'grammar'

parsed = Grammar.parse(text)
p parsed.dump