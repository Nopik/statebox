Q = require 'q'

class Storage
	constructor: (@options = {})->
		@options[ 'processDelayMs' ] ?= 100
		@processingRunning = false
		@processingStopRequested = false
		@processing = Q.resolve({})

	process: ->
		@processing.then =>
			q = Q.defer()

			@processingRunning = true
			@processing = q.promise

			p = =>
				if @processingStopRequested == false
					@getActiveContext().then (ctx, triggerName, triggerValues)=>
						@handleContext( ctx, triggerName, triggerValues ).then (ctx)=>
							@updateContext( ctx )
						.fin =>
							process.nextTick p
					, =>
						setTimeout p, @options[ 'processDelayMs' ]
				else
					@processingStopRequested = false
					@processingRunning = false
					q.resolve({})

			p()

			q.promise

	stopProcessing: (cb)->
		@processingStopRequested = true
		@processing.fin ->
			cb()

	isProcessing: ->
		@processingRunning

	isStopping: ->
		@processingStopRequested

	handleContext: (ctx, triggerName, triggerValues)->
		q = Q.defer()

		q.resolve({})

		q.promise

	#Methods below are stubs, showing interface
	connect: ->
		Q.resolve({})

	disconnect: ->
		Q.resolve({})

	getActiveContext: ->
		Q.reject({})

	getGraphs: ->
		Q.resolve([])

	destroyGraph: (graph_id)->
		Q.resolve({})

	saveGraph: (graph)->
		#should set graph.id
		Q.resolve({})

	saveContext: (ctx)->
		#should set ctx.id
		Q.resolve({})

	getContexts: (graph_id)->
		Q.resolve([])

	getContext: (graph_id, context_id)->
		Q.reject({})

	destroyContext: (graph_id, context_id)->
		Q.reject({})

	addTrigger: (graph_id, context_id, name, values, source)->
		Q.reject({})

module.exports = Storage
