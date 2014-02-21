Q = require 'q'
_ = require 'underscore'
Storage = require '../storage'
Graph = require '../graph'
Context = require '../context'
mongoose = require 'mongoose'
utils = require '../utils'

#mongoose.set 'debug', true

ProcessingState =
	Idle: 0
	Busy: 1
	Failed: 2

GraphSchema = mongoose.Schema
	source: String
	data: String
, { safe: { w: 1 } }

TriggerSchema = mongoose.Schema
	name: String
	values: String

TimerSchema = mongoose.Schema
	count: Number
	at: Number
	expiry: Number
	interval: Number
	ticks: Number

TickSchema = mongoose.Schema
	name: String
	at: Number
	number: Number

ContextSchema = mongoose.Schema
	graph_id: String
	values: String
	status: Number
	version:
		type: Number
		default: 0
	processed:
		type: Number
		default: ProcessingState.Idle
	triggers: [ TriggerSchema ]
	timers: mongoose.Schema.Types.Mixed
	ticks: []
, { safe: { w: 1 } }

GraphSchema.methods.getGraph = (storage)->
	g = new Graph @source, storage
	g.id = @_id
	g

ContextSchema.methods.getContext = (storage)->
	c = new Context @graph_id, storage, JSON.parse @values
	c.id = @_id
	c.status = @status
	c.version = @version
	c

nextTick = (ctx, tick)->
	res = undefined

	timer = ctx.currentTimer
	now = Date.now()

	if ctx.status = Context.Status.Active
		if timer?
			if (!timer.expiry?) || (timer.expiry == 0) || (timer.expiry > (now + timer.interval))
				if (timer.count == 0) || (timer.count > tick.number)
					res =
						name: tick.name
						number: tick.number + 1
						at: now + timer.interval

	res

ContextSchema.index { "triggers.0._id": 1 }
ContextSchema.index { "ticks.0.at": 1 }
ContextSchema.index { "ticks.0.name": 1 }

GraphModel = mongoose.model 'Graph', GraphSchema
ContextModel = mongoose.model 'Context', ContextSchema

class MongoStorage extends Storage
	@mongoose: mongoose

	constructor: (@url, options)->
		super( options )

	connect: ->
		mongoose.connect @url
		@db = mongoose.connection

		q = Q.defer()

		f = ->
			@db.removeListener 'error', g
			q.reject new Error "Unable to connect to DB"

		g = =>
			@db.removeListener 'error', f
			q.resolve({})

		@db.once 'error', f

		@db.once 'open', g

		q.promise

	disconnect: ->
		q = Q.defer()

		@db.close ->
			q.resolve({})

		q.promise

	# Graph

	saveGraph: (graph)->
		model = new GraphModel
			source: graph.source
			data: JSON.stringify graph.serialize()

		q = Q.defer()

		model.save (err, g)=>
			if !err
				graph.id = g._id
				q.resolve graph
			else
				q.reject err

		q.promise

	destroyGraph: (graph_id)->
		q = Q.defer()

		GraphModel.remove { _id: graph_id }, (err)=>
			if !err
				q.resolve {}
			else
				q.reject err

		q.promise

	getGraph: (graph_id)->
		q = Q.defer()

		GraphModel.findOne { _id: graph_id }, (err, model)=>
			if !err
				q.resolve model.getGraph( this )
			else
				q.reject err

		q.promise

	getGraphs: ->
		q = Q.defer()

		GraphModel.find {}, (err, models)=>
			if !err
				q.resolve _.collect models, (model)=>
					model.getGraph( this )
			else
				q.reject err

		q.promise

	# Context

	registerContext: (ctx)->
		ctx.queuedTriggers = []
		ctx.queuedExtTriggers = []
		ctx.queuedTimersAdd = []
		ctx.queuedTimersDel = []

	saveContext: (ctx)->
		model = new ContextModel
			values: JSON.stringify ctx.values.serialize()
			graph_id: ctx.graph_id
			status: ctx.status
			version: 1
			processed: ProcessingState.Busy

		q = Q.defer()

		model.save (err, c)=>
			if !err
				ctx.id = c._id
				ctx.version = c.version
				q.resolve ctx
			else
				q.reject err

		q.promise.then =>
			@updateContext ctx

	getContexts: (graph_id)->
		q = Q.defer()

		ContextModel.find { graph_id: graph_id }, (err, models)=>
			if !err
				q.resolve _.collect models, (model)=>
					model.getContext( this )
			else
				q.reject err

		q.promise

	getContextModel: (graph_id, context_id)->
		q = Q.defer()

		ContextModel.findOne { _id: context_id, graph_id: graph_id }, (err, model)=>
			if !err
				q.resolve model
			else
				q.reject err

		q.promise

	getContext: (graph_id, context_id)->
		@getContextModel( graph_id, context_id ).then (model)=>
			if model?
				model.getContext( this )
			else
				model

	destroyContext: (graph_id, context_id)->
		q = Q.defer()

		ContextModel.remove { _id: context_id, graph_id: graph_id }, (err)=>
			if !err
				q.resolve {}
			else
				q.reject err

		q.promise

	abortContext: (ctx)->
		q = Q.defer()

		update =
			$set:
				status: ctx.status
				version: ctx.version + 1
				processed: ProcessingState.Idle

		ContextModel.findOneAndUpdate { _id: ctx.id }, update, (err, c)=>
			if !err
				if c?
					q.resolve ctx
				else
					q.reject new Error "Unable to update context"
			else
				q.reject err

		q.promise

	updateContext: (ctx)->
		query =
			_id: ctx.id
			version: ctx.version
			processed: ProcessingState.Busy

		update =
			$set:
				status: ctx.status
				values: JSON.stringify ctx.values.serialize()

		updateFinish =
			$set:
				version: ctx.version + 1
				processed: ProcessingState.Idle

		pull = {}
		do_pull = false

		push = {}
		do_push = false

		if ctx.currentTrigger?
			pull[ 'triggers' ] =
				_id: ctx.currentTrigger._id
			do_pull = true

		if ctx.queuedTriggers.length > 0
			list = []

			for qt in ctx.queuedTriggers
				list.push
					name: qt.name
					values: JSON.stringify qt.values
					_id: new mongoose.Types.ObjectId()

			push[ 'triggers' ] =
				$each: list

			do_push = true

		if ctx.currentTick?
			update[ "timers.#{ctx.currentTick.name}.ticks" ] = ctx.currentTick.number

			next = nextTick ctx, ctx.currentTick

			if next?
				push[ 'ticks' ] =
					$each: [ next ]
					$slice: -100000000 #document size is 16M anyway
					$sort:
						at: 1

				do_push = true
			else
				ctx.queuedTimersDel.push
					name: ctx.currentTick.name

			pull[ 'ticks' ] =
				'$or': [
					{ name: ctx.currentTick.name, number: ctx.currentTick.number }
				]
			do_pull = true

		if ctx.queuedTimersAdd.length > 0
			if !push[ 'ticks' ]?
				push[ 'ticks' ] =
					$each: []
					$slice: -100000000 #document size is 16M anyway
					$sort:
						at: 1

			for qt in ctx.queuedTimersAdd
				update[ '$set' ][ "timers.#{qt.name}" ] =
					at: qt.at
					count: qt.count
					expiry: qt.expiry
					interval: qt.interval
					ticks: 0

				push[ 'ticks' ][ '$each' ].push
					name: qt.name
					at: qt.at
					number: 1

			do_push = true

		if ctx.queuedTimersDel.length > 0
			if !pull[ 'ticks' ]?
				pull[ 'ticks' ] =
					'$or': []
			do_pull = true

			update[ '$unset' ] = {}

			for qt in ctx.queuedTimersDel
				update[ '$unset' ][ "timers.#{qt.name}" ] = 1
				# delete set operation to avoid set-unset conflict in mongo update operation
				delete update[ "timers.#{qt.name}.ticks" ]

				pull[ 'ticks' ][ '$or' ].push
					name: qt.name

		if do_pull
			update[ '$pull' ] = pull

		res = Q.resolve( {} )

		if do_push
			res = res.then =>
				qq = Q.defer()

				ContextModel.findOneAndUpdate query, { $push: push }, (err, c)=>
					if !err?
						if c?
							qq.resolve {}
						else
							ctx.abort()
							@abortContext( ctx ).fin ->
								qq.reject new Error "Unable to push to context"
					else
						ctx.abort()
						@abortContext( ctx ).fin ->
							qq.reject err

				qq.promise

		res = res.then =>
			q = Q.defer()

			ContextModel.findOneAndUpdate query, update, (err, c)=>
				if !err
					if c?
						q.resolve {}
					else
						ctx.abort()
						@abortContext( ctx ).fin ->
							q.reject new Error "Unable to update context"
				else
					ctx.abort()
					@abortContext( ctx ).fin ->
						q.reject err

			q.promise

		if ctx.queuedExtTriggers.length > 0
			res = res.then =>
				res = utils.reduce ctx.queuedExtTriggers, (qet)=>
					@addTrigger qet.graph_id, qet.context_id, qet.name, qet.values
				, {}

				res.fail (r)=>
					ctx.abort()
					@abortContext( ctx ).fin ->
						Q.reject r

		res = res.then =>
			q = Q.defer()

			ContextModel.findOneAndUpdate query, updateFinish, (err, c)=>
				if !err
					if c?
						q.resolve {}
					else
						ctx.abort()
						@abortContext( ctx ).fin ->
							q.reject new Error "Unable to finish update context"
				else
					ctx.abort()
					@abortContext( ctx ).fin ->
						q.reject err

			q.promise

		res

	addTrigger: (graph_id, context_id, name, values)->
		query =
			_id: context_id
			graph_id: graph_id
			status: Context.Status.Active

		update =
			$push:
				triggers:
					name: name
					values: JSON.stringify values
					_id: new mongoose.Types.ObjectId()

		q = Q.defer()

		ContextModel.findOneAndUpdate query, update, (err, ctx)=>
			if !err
				q.resolve {}
			else
				q.reject err

		q.promise

	queueTrigger: (context, name, values)->
		context.queuedTriggers.push
			name: name
			values: values

		Q.resolve {}

	queueExtTrigger: (context, graph_id, context_id, name, values)->
		context.queuedExtTriggers.push
			graph_id: graph_id
			context_id: context_id
			name: name
			values: values

		Q.resolve {}

	startTimer: (ctx, name, options)->
		if options.interval > 0
			options.count = 0 if !options.count?
			options.expiry = 0 if !options.expiry?

			at = undefined

			if options.firstIn?
				at = options.firstIn + Date.now()

			if !at?
				at = Date.now() + options.interval

			if (options.expiry == 0) || ((options.expiry > 0) && at < options.expiry)
				ctx.queuedTimersAdd.push
					name: name
					at: at
					count: options.count
					expiry: options.expiry
					interval: options.interval

				Q.resolve {}
			else
				Q.resolve {} #timer already expired, not a fatal error
		else
			Q.reject new Error "Timer need positive interval"

	stopTimer: (ctx, name)->
		ctx.queuedTimersDel.push
			name: name

	getActiveContext: ->
		q = Q.defer()

		tickAt = Date.now()

		query =
			processed: ProcessingState.Idle
			status: Context.Status.Active
			$or: [
				"triggers.0._id":
					$ne: null
			,
				"ticks.0.at":
					$lte: tickAt
			]

		update =
			$set:
				processed: ProcessingState.Busy

		ContextModel.findOneAndUpdate query, update, (err, model)=>
			if !err
				if model?
					ctx = model.getContext( this )

					trigger = model.triggers[ 0 ]

					if trigger?
						ctx.currentTrigger = trigger

						q.resolve
							ctx: ctx
							triggerName: trigger.name
							triggerValues: JSON.parse trigger.values
					else
						tick = model.ticks[ 0 ]
						timer = model.timers[ tick?.name ]

						if timer? && (tick.number >= timer.ticks)
							if tick? && timer? && tick.at <= tickAt
								ctx.currentTick = tick
								ctx.currentTimer = timer

								q.resolve
									ctx: ctx
									triggerName: "timer.#{tick.name}"
									triggerValues: {}
							else
								q.reject new Error "Got pseudo-active context"
						else
							#Obsolete tick or invalid timer found, lets remove it and re-try
							remUpdate =
								"$pull":
									ticks:
										name: tick.name
										at: tick.at
										number: tick.number

							ContextModel.findOneAndUpdate { _id: ctx.id }, remUpdate, (err, c)=>
								q.reject new Error "Got stale tick or invalid timer"
				else
					q.reject new Error "No model found"
			else
				q.reject err

		q.promise

module.exports = MongoStorage
