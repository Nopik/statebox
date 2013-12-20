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

ContextSchema = mongoose.Schema
	graph_id: String
	values: String
	status: Number
	version: Number
	triggers: [ TriggerSchema ]
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

ContextSchema.index { "triggers.0._id": 1 }

GraphModel = mongoose.model 'Graph', GraphSchema
ContextModel = mongoose.model 'Context', ContextSchema

class MongoStorage extends Storage
	constructor: (@url, options)->
		super( options )

	connect: ->
		mongoose.connect @url
		@db = mongoose.connection

		q = Q.defer()

		@db.once 'error', ->
			q.reject new Error "Unable to connect to DB"

		@db.once 'open', ->
			q.resolve({})

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

		ContextModel.findOneAndUpdate { _id: ctx.id, version: ctx.version }, update, (err, c)=>
			if !err
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

#		@getContextModel( graph_id, context_id ).then (ctx)=>
#			if ctx.status == Context.Status.Active
#				trigger = ctx.triggers.create
#					name: name
#					values: JSON.stringify values
#
#				q = Q.defer()
#
#				update =
#					$push:
#						triggers: trigger
#
#					$set:
#						version: ctx.version + 1
#
#				ContextModel.findOneAndUpdate { _id: ctx.id, version: ctx.version }, update, (err, ctx)=>
#					if !err
#						if ctx?
#							q.resolve {}
#						else
#							#Either version got bumped, or context was deleted
#							@getContextModel( graph_id, context_id ).then (ctx1)=>
#								if ctx1?
#									if ctx1.version > ctx.version
#										res = @addTrigger graph_id, context_id, name, values
#
#										res.then (r)->
#											q.resolve r
#										, (r)->
#											q.reject r
#									else
#										q.reject new Error "Unable to add trigger"
#								else
#									q.reject new Error "Context does not exist"
#							, (r)->
#								q.reject r
#					else
#						q.reject err
#				, (r)->
#					q.reject r
#
#				q.promise
#			else
#				Q.reject new Error "Cannot add trigger to inactive context"

	getActiveContext: ->
		q = Q.defer()

		ContextModel.findOne { "triggers.0._id": { $ne: null }, status: Context.Status.Active }, (err, model)=>
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
						q.reject new Error "Got pseudo-active context"
				else
					q.reject {}
			else
				q.reject err

		q.promise

module.exports = MongoStorage
