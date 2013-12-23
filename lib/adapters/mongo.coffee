Q = require 'q'
_ = require 'underscore'
Storage = require '../storage'
Graph = require '../graph'
Context = require '../context'
mongoose = require 'mongoose'

#mongoose.set 'debug', true

GraphSchema = mongoose.Schema
	source: String
	data: String
, { safe: { w: 1 } }

TriggerSchema = mongoose.Schema
	name: String
	values: String

TimerSchema = mongoose.Schema
	count: Number
	firstIn: Number
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
	version: Number
	triggers: [ TriggerSchema ]
	timers: mongoose.Schema.Types.Mixed
	ticks: [ TickSchema ]
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

	saveContext: (ctx)->
		model = new ContextModel
			values: JSON.stringify ctx.values.serialize()
			graph_id: ctx.graph_id
			status: ctx.status
			version: 1

		q = Q.defer()

		model.save (err, c)=>
			if !err
				ctx.id = c._id
				ctx.version = c.version
				q.resolve ctx
			else
				q.reject err

		q.promise

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

	updateContext: (ctx)->
		q = Q.defer()

		update =
			$set:
				status: ctx.status
				values: JSON.stringify ctx.values.serialize()
				version: ctx.version + 1

		if ctx.currentTrigger?
			update[ "$pull" ] =
				triggers:
					_id: ctx.currentTrigger._id

		remove = false

		if ctx.currentTick?
			update[ "times.#{ctx.currentTick.name}.ticks" ] = ctx.currentTick.number

			next = nextTick ctx, ctx.currentTick

			if next?
				remove = true

				update[ "$push" ] =
					ticks:
						$each: [ next ]
						$slice: -100000000 #document size is 16M anyway
						$sort:
							number: 1
			else
				update[ "$pull" ] =
					ticks:
						name: ctx.currentTick.name
						at: ctx.currentTick.at
						number: ctx.currentTick.number

		ContextModel.findOneAndUpdate { _id: ctx.id, version: ctx.version }, update, (err, c)=>
			if !err
				if remove
					remUpdate =
						"$pull":
							ticks:
								name: ctx.currentTick.name
								at: ctx.currentTick.at
								number: ctx.currentTick.number

					ContextModel.findOneAndUpdate { _id: ctx.id }, remUpdate, (err, c)->
						#ignore result
						q.resolve ctx
				else
					q.resolve ctx
			else
				q.reject err

		q.promise

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

	startTimer: (graph_id, context_id, name, options)->
		if options.interval > 0
			query =
				_id: context_id
				graph_id: graph_id
				status: Context.Status.Active

			options.count = 0 if !options.count?
			options.expiry = 0 if !options.expiry?

			s =
				timers: {}

			s.timers[ name ] =
				count: options.count
				firstIn: options.firstIn
				expiry: options.expiry
				interval: options.interval
				ticks: 0

			at = options.firstIn + Date.now()

			if !at?
				at = Date.now() + options.interval

			if (options.expiry == 0) || ((options.expiry > 0) && at < options.expiry)
				update =
					$set: s
					$push:
						ticks:
							$each: [
								name: name
								at: at
								number: 1
							]
							$slice: -100000000 #document size is 16M anyway
							$sort:
								number: 1

				q = Q.defer()

				ContextModel.findOneAndUpdate query, update, (err, ctx)=>
					if !err
						q.resolve {}
					else
						q.reject err

				q.promise
			else
				Q.resolve {} #timer already expired, not a fatal error
		else
			Q.reject new Error "Timer need positive interval"

	stopTimer: (graph_id, context_id, name)->
		query =
			_id: context_id
			graph_id: graph_id

		s = {}
		s[ "timers.#{name}" ] = ""

		update =
			$unset: s
			$pull:
				ticks:
					name: name

		q = Q.defer()

		ContextModel.findOneAndUpdate query, update, (err, ctx)=>
			if !err
				q.resolve {}
			else
				q.reject err

		q.promise

	getActiveContext: ->
		q = Q.defer()

		tickAt = Date.now()

		query =
			$or: [
				"triggers.0._id":
					$ne: null
				status: Context.Status.Active
			,
				"ticks.0.at":
					$lte: tickAt
			]


		ContextModel.findOne query, (err, model)=>
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

						if tick.number >= timer.ticks
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
							#Obsolete tick found, lets remove it and re-try
							remUpdate =
								"$pull":
									ticks:
										name: tick.name
										at: tick.at
										number: tick.number

							ContextModel.findOneAndUpdate { _id: ctx.id }, remUpdate, (err, c)=>
								q.reject new Error "Got stale tick"
				else
					q.reject new Error "No model found"
			else
				q.reject err

		q.promise

module.exports = MongoStorage
