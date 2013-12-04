State = require './state'

class Context
	constructor: (@graph_id, @storage, @values = {})->
		@graph = @storage.getGraph( @graph_id )

		@currentState = null

		startState = @graph.getStartState()

		if startState?

			@_moveToState( startState )
		else
			throw "Graph #{@graph_id} has no start state"

	destroy: ->
		@storage.destroyContext( @graph_id, @id )

	trigger: (name, values)->

	getValue: (name)->

	setValue: (name)->

	_moveToState: (state)->
		@currentState?.leave()

		@currentState = state

		@currentState?.enter()

		if @currentState.hasFlag( State.Flags.Finish )
			false
			#TODO: what to do here?

module.exports = Context
