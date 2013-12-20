chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
should = chai.should()

util = require 'util'
_ = require 'underscore'
mongoose = require 'mongoose'
Q = require 'q'

StateBox = require '../lib/statebox'
utils = require '../lib/utils'
Runners = require '../lib/runners'
SpecHelpers = require './spec_helpers'

url = 'mongodb://localhost/statebox-test'

actions = _.clone SpecHelpers.actions
actions.trigger = new Runners.Trigger()
actions.startTimer = new Runners.StartTimer()

new_storage = ->
	new StateBox.StorageAdapters.Mongo( url, { processDelayMs: 100 } )

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

		it 'manages contexts', (done)->
			@mgr.buildGraph( 'state a[start] {}' ).then (graph)=>
				@mgr.getContexts( graph.id ).then (ctxs0)=>
					ctxs0.should.be.an.instanceOf Array
					ctxs0.length.should.eql 0

					@mgr.runGraph( graph.id ).then (ctx)=>
						should.exist ctx
						should.exist ctx.id
						ctx.id.toString().length.should.eql 24 #Mongo ID length

						@mgr.getContexts( graph.id ).then (ctxs1)=>
							ctxs1.should.be.an.instanceOf Array
							ctxs1.length.should.eql 1
							ctxs1[ 0 ].should.be.instanceOf StateBox.Context
							ctxs1[ 0 ].id.toString().should.eql ctx.id.toString()

							@mgr.getContext( graph.id, ctx.id ).then (ctx1)=>
								should.exist ctx1
								ctx1.should.be.instanceOf StateBox.Context
								ctx1.id.toString().should.eql ctx.id.toString()
								ctx1.graph_id.toString().should.eql graph.id.toString()
								ctx1.status.should.eql StateBox.Context.Status.Active
								ctx1.getValue( StateBox.Context.StateValueName ).should.eql 'a'

								@mgr.abortContext( graph.id, ctx.id ).then =>
									@mgr.getContext( graph.id, ctx.id ).then (ctx1a)=>
										ctx1a.status.should.eql StateBox.Context.Status.Aborted
										ctx1a.getValue( StateBox.Context.StateValueName ).should.eql 'a'

										ctx.destroy().then =>
											@mgr.getContexts( graph.id ).then (ctxs2)=>
												ctxs2.should.be.an.instanceOf Array
												ctxs2.length.should.eql 0

												@mgr.getContext( graph.id, ctx.id ).then (ctx2)=>
													should.not.exist ctx2

													done()
			.fail (r)->
				done(r)

		it 'updates contexts', (done)->
			@mgr.buildGraph( 'state a[start] {}' ).then (graph)=>
				@mgr.runGraph( graph.id ).then (ctx)=>
					ctx.setValue 'foo', 42
					ctx.setValue 'bar', [ 'foo' ]

					@storage.updateContext( ctx ).then =>
						@mgr.getContext( graph.id, ctx.id ).then (ctx1)=>
							ctx1.getValue( 'foo' ).should.eql 42
							ctx1.getValue( 'bar' ).should.eql [ 'foo' ]
							done()

		it 'adds trigger', (done)->
			@mgr.buildGraph( 'state a[start] {}' ).then (graph)=>
				@mgr.runGraph( graph.id ).then (ctx)=>
					@mgr.addTrigger( graph.id, ctx.id, 't1', { foo: 42 } ).then =>
						done()
			.fail (r)->
				done( r )

	describe 'Processing', ->
		beforeEach (done)->
			source = """
				state a[start] {
					@test.name {
						= ctx.foo = 42;
					};

					@b -> b {};
					@t -> t {};
				};

				state b {
					@c -> c {};
				};

				state c {
					@c1 {
						trigger 'd';
					};

					@d -> d {};
				};

				state d {
					-> {
						= ctx.bar = 1;
					}
				}

				state t {
					-> {
						startTimer 't1', 100, { firstIn: 100, count: 42 };
					}
				}
"""

			@storage = new_storage()
			@storage.setActions actions
			@mgr = new StateBox.Manager( @storage )
			@mgr.init().then =>
				@mgr.buildGraph( source ).then (graph)=>
					@graph = graph

					@mgr.runGraph( @graph.id ).then (ctx)=>
						@ctx = ctx

						@mgr.startProcessing().then ->
							done()
			.fail (r)->
				done( r )

		afterEach (done)->
			@mgr.stopProcessing =>
				@storage.disconnect().then ->
					done()
			.fail (r)->
				done( r )

		it 'initializes', ->

		it 'performs processing', (done)->
			tName = 'test.name'
			tVals =
				foo: 42

			processed = (ctx, triggerName)=>
				try
					ctx.id.should.eql @ctx.id
					triggerName.should.eql tName
					done()
				catch e
					done( e )

			@storage.on 'processedTrigger', processed

			@mgr.addTrigger( @graph.id, @ctx.id, tName, tVals ).then =>
				true
			.fail (r)->
				done( r )

		it 'changes states', (done)->
			fs = [
				(ctx, name)=> #b
				(ctx, name)=> #c
					SpecHelpers.sendTriggers @mgr, @graph.id, @ctx.id, [
						[ 'c1', {} ]
					]
				(ctx, name)=> #c1
				(ctx, name)=> #d
					v = ctx.getValue( 'bar' )
					should.exist v
					v.should.eql 1
			]

			SpecHelpers.waitForTriggers @storage, fs, done

			SpecHelpers.sendTriggers @mgr, @graph.id, @ctx.id, [
				[ 'b', {} ]
				[ 'c', {} ]
			]

		it 'adds timer', (done)->
			fs = [
				(ctx, name)=> #t
			]

			SpecHelpers.waitForTriggers @storage, fs, done

			SpecHelpers.sendTriggers @mgr, @graph.id, @ctx.id, [
				[ 't', {} ]
			]
