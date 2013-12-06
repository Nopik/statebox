State = require './state'
Q = require 'q'

class Context
	@StateValueName: 'state'

	@Status:
		Active: 1
		Finished: 2
		Failed: 3
		Aborted: 4

	constructor: (@graph_id, @storage, @values = {})->
		@values ?= {}
		@status = Context.Status.Active
		@setValue Context.StateValueName, null

	init: ->
		@storage.getGraph( @graph_id ).then (graph)=>
			startState = graph.getStartState()

			if startState?
				@_moveToState( startState )
				Q.resolve({})
			else
				@status = Context.Status.Failed
				Q.reject({})

	abort: ->
		@status = Context.Status.Aborted

	destroy: ->
		@storage.destroyContext( @graph_id, @id )

	trigger: (name, values)->
		@storage.getGraph( @graph_id ).then (graph)=>
			nextState = graph.getNextState @_getCurrentState(), name
			if nextState?
				@_moveToState( values )

	getValue: (name)->
		@values[ name ]

	setValue: (name, value)->
		@values[ name ] = value

	_moveToState: (state, values = {})->
		cs = @_getCurrentState()
		cs?.leave( this, values )

		@setValue Context.StateValueName, state

		state?.enter( this, values )

		if state.hasFlag( State.Flags.Finish )
			@status = Context.Status.Finished

	_getCurrentState: ->
		@getValue Context.StateValueName

module.exports = Context
