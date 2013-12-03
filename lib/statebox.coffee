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

class Graph
	constructor: (@source, @storage)->
		@_parse()

	destroy: ->
		@storage.destroyGraph( @id )

	_parse: ->

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

	runGraph: (graph_id)->
		ctx = new Context( graph_id, @storage )
		@storage.saveContext( ctx )
		ctx

	getContexts: (graph_id)->
		@storage.getContexts( graph_id )

	getContext: (graph_id, context_id)->
		@storage.getContext( graph_id, context_id )

class Context
	constructor: (@graph_id, @storage)->

	destroy: ->
		@storage.destroyContext( @graph_id, @id )

	#TODO: trigger? get values? set values? get state?

module.exports =
	Graph: Graph
	Context: Context
	Manager: Manager
	Storage: Storage
