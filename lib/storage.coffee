Q = require 'q'
events = require 'events'

class Storage extends events.EventEmitter
	constructor: (@options = {})->
		@options[ 'processDelayMs' ] ?= 100
		@processingRunning = false
		@processingStopRequested = false
		@processing = Q.resolve({})

	process: ->
		old_processing = @processing

		@processing.then =>
			q = Q.defer()

			@processingRunning = true
			@processing = q.promise

			@emit 'processing'

			p = =>
				if @processingStopRequested == false
					@getActiveContext().then (trigInfo)=>
						ctx = trigInfo.ctx
						triggerName = trigInfo.triggerName
						triggerValues = trigInfo.triggerValues

						@handleContext( ctx, triggerName, triggerValues ).then (ctx)=>
							@updateContext( ctx )
							@emit 'processedTrigger', ctx, triggerName
						.fin =>
							process.nextTick p
					, =>
						@emit 'noActiveContext'
						setTimeout p, @options[ 'processDelayMs' ]
				else
					@processingStopRequested = false
					@processingRunning = false
					@emit 'stoppedProcessing'
					q.resolve({})

			p()

			old_processing

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

		q.resolve( ctx )

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

	updateContext: (ctx)->
		Q.resolve({})

module.exports = Storage
