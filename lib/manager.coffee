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
		Context.run graph_id, @storage, values

	addTrigger: (graph_id, context_id, name, values)->
		@storage.addTrigger graph_id, context_id, name, values

	getContexts: (graph_id)->
		@storage.getContexts( graph_id )

	getContext: (graph_id, context_id)->
		@storage.getContext( graph_id, context_id )

	getContextValue: (graph_id, context_id, name)->
		@storage.getContext( graph_id, context_id ).then (ctx)->
			ctx.getValue( name )

#TODO: to have this, we'd need something like @storage.updateContext( onlyIfNotBeingProcessed: true ),
#and possibly retry after some time if the context is currently processed.
#	setContextValue: (graph_id, context_id, name, value)->
#		@storage.getContext( graph_id, context_id ).then (ctx)=>
#			ctx.setValue( name, value )
#			@storage.updateContext ctx

	abortContext: (graph_id, context_id)->
		@getContext( graph_id, context_id ).then (ctx)=>
			ctx.abort()
			@storage.abortContext ctx

	startProcessing: ->
		@storage.process()

	stopProcessing: (cb)->
		@storage.stopProcessing cb

	isProcessing: ->
		@storage.isProcessing()

	isStopping: ->
		@storage.isStopping()

module.exports = Manager
