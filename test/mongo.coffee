chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
should = chai.should()

util = require 'util'
_ = require 'underscore'
mongoose = require 'mongoose'

StateBox = require '../lib/statebox'

url = 'mongodb://localhost/statebox-test'

new_storage = ->
	new StateBox.StorageAdapters.Mongo( url )

describe 'Mongo Storage', ->
	beforeEach (done) ->
		mongoose.connect url
		connection = mongoose.connection
		connection.once 'open', ->
			connection.db.dropDatabase ->
				connection.close ->
					done()

	describe 'System', ->
		it 'connects', (done)->
			storage = new_storage()

			storage.connect().then ->
				storage.disconnect().then ->
					done()

	describe 'Operation', ->
		beforeEach (done)->
			@storage = new_storage()
			@mgr = new StateBox.Manager( @storage )
			@mgr.init().then ->
				done()
			.fail (r)->
				done r

		afterEach (done)->
			@storage.disconnect().then ->
				done()

		it 'persists graph', (done)->
			@mgr.buildGraph( 'state a {}' ).then (graph)=>
				id = graph.id

				should.exist id
				id.toString().length.should.eql 24 #24: length of Mongo IDs

				graph.destroy().then =>
					done()
			.fail (r)->
				done( r )

		it 'finds graph', (done)->
			@mgr.buildGraph( 'state a {}' ).then (g)=>
				@mgr.getGraph( g.id ).then (graph)=>
					should.exist graph
					should.exist graph.getState( 'a' )

					graph.source.should.eql g.source
					graph.serialize().should.eql g.serialize()

					done()
			.fail (r)->
				done( r )

		it 'finds all graphs', (done)->
			@mgr.getGraphs().then (graphs)=>
				should.exist graphs
				graphs.length.should.eql 0

				@mgr.buildGraph( 'state a {}' ).then (g)=>
					@mgr.getGraphs().then (graphs)=>
						should.exist graphs
						graphs.length.should.eql 1

						graph = graphs[ 0 ]

						should.exist graph
						graph.should.be.instanceOf StateBox.Graph
						should.exist graph.getState( 'a' )

						graph.source.should.eql g.source
						graph.serialize().should.eql g.serialize()

						graph.destroy().then =>
							@mgr.getGraphs().then (graphs)=>
								should.exist graphs
								graphs.length.should.eql 0

								done()
			.fail (r)->
				done( r )
