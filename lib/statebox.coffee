#This class is a stub, shows interface
class Storage
	constructor: ->

	connect: ->

	disconnect: ->

	getGraphs: ->

	destroyGraph: (graph_id)->

	saveGraph: (graph)->
		#should set graph.id

	saveContext: (ctx)->
		#should set ctx.id

	getContexts: (graph_id)->

	getContext: (graph_id, context_id)->

	destroyContext: (graph_id, context_id)->

class Action
	constructor: (@type, @values = {}, @label = '')->

	execute: ->

class State
	constructor: (@name = '', @enterActions = [], @leaveActions = [], @flags = 0)->

	hasFlag: (flag)->
		(@flags & flag) != 0x00

	leave: ->

	enter: ->

	@Flags:
		Start: 0x01
		Finish: 0x02

class Edge
	constructor: (@fromState, @toState)->

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

class Manager
	constructor: (@storage)->
		@storage.connect()

	buildGraph: (source)->
		graph = new Graph( source, @storage )

		@storage.saveGraph( graph )

		graph

	getGraphs: ->
		@storage.getGraphs()

	getGraph: (graph_id)->
		@storage.getGraph( graph_id )

	runGraph: (graph_id, values)->
		ctx = new Context( graph_id, @storage, values )
		@storage.saveContext( ctx )
		ctx

	getContexts: (graph_id)->
		@storage.getContexts( graph_id )

	getContext: (graph_id, context_id)->
		@storage.getContext( graph_id, context_id )

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

	getCurrentStateName: ->
		@currentState.name

	_moveToState: (state)->
		@currentState?.leave()

		@currentState = state

		@currentState?.enter()

		if @currentState.hasFlag( State.Flags.Finish )
			false
			#TODO: what to do here?

module.exports =
	Graph: Graph
	Context: Context
	Manager: Manager
	Storage: Storage
