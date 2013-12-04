Graph = require './graph'
Context = require './context'

class Manager
	@Error:
		Generic: -1
		NotFound: -2

	constructor: (@storage)->

	init: ->
		@storage.connect()

	buildGraph: (source)->
		graph = new Graph( source, @storage )

		@storage.saveGraph( graph ).then ->
			graph

	getGraphs: ->
		@storage.getGraphs()

	getGraph: (graph_id)->
		@storage.getGraph( graph_id )

	runGraph: (graph_id, values)->
		ctx = new Context( graph_id, @storage, values )
		ctx.init().then =>
			@storage.saveContext( ctx ).then ->
				ctx

	addTrigger: (graph_id, context_id, name, values, source = '')->
		@storage.addTrigger graph_id, context_id, name, values, source

	getContexts: (graph_id)->
		@storage.getContexts( graph_id )

	getContext: (graph_id, context_id)->
		@storage.getContext( graph_id, context_id )

	getContextValue: (graph_id, context_id, name)->
		@storage.getContext( graph_id, context_id ).then (ctx)->
			ctx.getValue( name )

	abortContext: (graph_id, context_id)->
		@getContext( graph_id, context_id ).then (ctx)=>
			ctx.abort()
			@storage.updateContext ctx

	startProcessing: ->
		@storage.process()

	stopProcessing: (cb)->
		@storage.stopProcessing cb

module.exports = Manager
