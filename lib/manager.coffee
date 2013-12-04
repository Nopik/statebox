Graph = require './graph'
Context = require './context'

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

module.exports = Manager
