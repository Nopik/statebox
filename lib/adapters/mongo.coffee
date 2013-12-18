Q = require 'q'
_ = require 'underscore'
Storage = require '../storage'
Graph = require '../graph'
mongoose = require 'mongoose'

#mongoose.set 'debug', true

GraphSchema = mongoose.Schema
	source: String
	data: String
, { safe: { w: 1 } }

GraphModel = mongoose.model 'Graph', GraphSchema

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

	_buildGraph: (model)->
		g = new Graph model.source, this
		g.id = model._id
		g

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
		#should set ctx.id
		Q.resolve({})

	updateContext: (ctx)->
		Q.resolve({})

	getContexts: (graph_id)->
		Q.resolve([])

	getContext: (graph_id, context_id)->
		Q.reject({})

	destroyContext: (graph_id, context_id)->
		Q.reject({})


	addTrigger: (graph_id, context_id, name, values, source)->
		Q.reject({})

	getActiveContext: ->
		Q.reject({})

module.exports = MongoStorage
