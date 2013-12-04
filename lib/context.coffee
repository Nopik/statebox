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

	destroy: ->
		@storage.destroyContext( @graph_id, @id )

	trigger: (name, values)->

	getValue: (name)->

	setValue: (name, value)->
		@values[ name ] = value

	_moveToState: (state)->
		cs = @getValue Context.StateValueName
		cs?.leave()

		@setValue Context.StateValueName, state

		state?.enter()

		if state.hasFlag( State.Flags.Finish )
			@status = Context.Status.Finished

module.exports = Context
