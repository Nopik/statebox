State = require './state'
Values = require './values'
Q = require 'q'

class Context
	@StateValueName: 'state'

	@Status:
		Active: 1
		Finished: 2
		Failed: 3
		Aborted: 4

	constructor: (@graph_id, @storage, values = {})->
		values ?= {}
		@values = new Values.Holder values
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
				Q.reject( new Error( "Graph has no start state" ) )

	abort: ->
		@status = Context.Status.Aborted

	destroy: ->
		@storage.destroyContext( @graph_id, @id )

	trigger: (name, values)->
		@storage.getGraph( @graph_id ).then (graph)=>
			cs = @_getCurrentState()

			values = new Values.Holder values
			cs.runTrigger( this, name, values ).then (nextStateName)=>
				if nextStateName?
					nextState = graph.getState( nextStateName )
					if nextState?
						@_moveToState( nextState, values )

	getValue: (name)->
		@values.get name

	setValue: (name, value)->
		@values.set name, value

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
