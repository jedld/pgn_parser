require_relative 'lib/pgn_parser'
require 'json'

@pgn_data = File.read(File.join(File.dirname(__FILE__),'11.pgn'))

pgn = PgnParser.new(@pgn_data)

puts pgn.parse.to_json
