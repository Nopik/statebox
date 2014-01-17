Q = require 'q'
events = require 'events'
log = log4js?.getLogger 'storage'

#TODO
if !log?
	log =
		info: ->
		trace: ->

class Storage extends events.EventEmitter
	constructor: (@options = {})->
		@options[ 'processDelayMs' ] ?= 100
		@processingRunning = false
		@processingStopRequested = false
		@processing = Q.resolve({})
		@actions = {}

	setActions: (actions)->
		@actions = actions

	getActions: (actions)->
		@actions

	process: ->
		if (@processingRunning != true) || (@processingStopRequested != false)
			old_processing = @processing

			@processing.then =>
				q = Q.defer()

				@processingRunning = true
				@processing = q.promise

				@emit 'processing'
				log.info 'processing started'

				p = =>
					if @processingStopRequested == false
						@getActiveContext().then (trigInfo)=>
							ctx = trigInfo.ctx
							triggerName = trigInfo.triggerName
							triggerValues = trigInfo.triggerValues

							log.trace 'started to process trigger', triggerName, 'for', ctx.id

							@handleContext( ctx, triggerName, triggerValues ).then (ctx)=>
								@updateContext( ctx ).then =>
	#								console.log ctx.id, ctx.version, triggerName
									@emit 'processedTrigger', ctx, triggerName
									log.trace 'processed trigger', triggerName, 'for', ctx.id
							.fail (r)=>
								ctx.abort()
								@updateContext( ctx )
								console.log "Error during trigger processing: #{r}"
	#						.fin =>
							process.nextTick p
						, =>
							@emit 'noActiveContext'
							setTimeout p, @options[ 'processDelayMs' ]
					else
						@processingStopRequested = false
						@processingRunning = false
						@emit 'stoppedProcessing'
						log.info 'processing stopped'
						q.resolve({})

				p()

				old_processing
		else
			Q.resolve {}

	stopProcessing: (cb)->
		@processingStopRequested = true
		@processing.fin ->
			cb()

	isProcessing: ->
		@processingRunning

	isStopping: ->
		@processingStopRequested

	handleContext: (ctx, triggerName, triggerValues)->
		ctx.processTrigger( triggerName, triggerValues ).then ->
			ctx

	#Methods below are stubs, showing interface
	connect: ->
		Q.resolve({})

	disconnect: ->
		Q.resolve({})

	registerContext: (ctx)->

	getActiveContext: ->
		Q.reject({})

	getGraph: (graph_id)->
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

	abortContext: (context)->
		Q.reject({})

	destroyContext: (graph_id, context_id)->
		Q.reject({})

	addTrigger: (graph_id, context_id, name, values)->
		Q.reject({})

	queueTrigger: (context, name, values)->
		Q.reject({})

	queueExtTrigger: (context, graph_id, context_id, name, values)->
		Q.reject({})

	updateContext: (ctx)->
		Q.resolve({})

	startTimer: (context, name, options)->
		Q.reject({})

	stopTimer: (context, name)->
		Q.reject({})

module.exports = Storage
