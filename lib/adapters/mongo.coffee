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

ContextSchema = mongoose.Schema
	graph_id: String
	values: String
	status: Number
, { safe: { w: 1 } }

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

	_buildGraph: (model)->
		g = new Graph model.source, this
		g.id = model._id
		g

	_buildContext: (model)->
		c = new Context model.graph_id, this, JSON.parse model.values
		c.id = model._id
		c.status = model.status
		c


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
				q.resolve @_buildGraph( model )
			else
				q.reject err

		q.promise

	getGraphs: ->
		q = Q.defer()

		GraphModel.find {}, (err, models)=>
			if !err
				q.resolve _.collect models, (model)=>
					@_buildGraph( model )
			else
				q.reject err

		q.promise


	saveContext: (ctx)->
		#TODO: values.vals, state.serialize()

		model = new ContextModel
			values: JSON.stringify ctx.values
			graph_id: ctx.graph_id
			status: ctx.status

		q = Q.defer()

		model.save (err, c)=>
			if !err
				ctx.id = c._id
				q.resolve ctx
			else
				q.reject err

		q.promise

	getContexts: (graph_id)->
		q = Q.defer()

		ContextModel.find { graph_id: graph_id }, (err, models)=>
			if !err
				q.resolve _.collect models, (model)=>
					@_buildContext( model )
			else
				q.reject err

		q.promise

	getContext: (graph_id, context_id)->
		q = Q.defer()

		ContextModel.findOne { _id: context_id, graph_id: graph_id }, (err, model)=>
			if !err
				if model?
					q.resolve @_buildContext( model )
				else
					q.resolve model
			else
				q.reject err

		q.promise

	destroyContext: (graph_id, context_id)->
		q = Q.defer()

		ContextModel.remove { _id: context_id, graph_id: graph_id }, (err)=>
			if !err
				q.resolve {}
			else
				q.reject err

		q.promise

	updateContext: (ctx)->
		Q.resolve({})


	addTrigger: (graph_id, context_id, name, values, source)->
		Q.reject({})

	getActiveContext: ->
		Q.reject({})

module.exports = MongoStorage
