State = require './state'

class Graph
	constructor: (@source, @storage)->
		@_parse()

	destroy: ->
		@storage.destroyGraph( @id )

	_parse: ->
		@states = {}
		@edges = {}

		@_addState 'start', [], [], [], State.Flags.Start

	_addState: (name, enterActions, leaveActions, triggerActions, flags)->
		@states[ name ] = new State( name, enterActions, leaveActions, triggerActions, flags )

	getState: (name)->
		@states[ name ]

	getStartState: ->
		for name, state of @states
			if state.hasFlag( State.Flags.Start )
				return state
		undefined

	getNextState: (stateName, triggerName)->
		name = @edges[ stateName ]?[ triggerName ]

		if name?
			@getState( name )
		else
			undefined

module.exports = Graph
