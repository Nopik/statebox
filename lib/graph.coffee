State = require './state'

class Graph
	constructor: (@source, @storage)->
		@_parse()

	destroy: ->
		@storage.destroyGraph( @id )

	_parse: ->
		@states = {}
		@edges = {}

		@_addState 'start', [], [], State.Flags.Start

	_addState: (name, enterActions, leaveActions, flags)->
		@states[ name ] = new State( name, enterActions, leaveActions, flags )

	getState: (name)->
		@states[ name ]

	getStartState: ->
		for name, state of @states
			if state.hasFlag( State.Flags.Start )
				return state
		undefined

module.exports = Graph
