State = require './state'
Parser = require '../src/graph'

class Graph
	constructor: (@source, @storage)->
		@states = Parser.parser.parse @source

	destroy: ->
		@storage.destroyGraph( @id )

	getState: (name)->
		for state in @states
			if state.name == name
				return state
		undefined

	getStartState: ->
		for state in @states
			if state.hasFlag( State.Flags.Start )
				return state
		undefined

module.exports = Graph
