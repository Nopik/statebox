should = require 'should'
StateBox = require '../lib/statebox'
_ = require 'underscore'
Q = require 'q'

class TestStorage extends StateBox.Storage
	constructor: ->
		@connect_calls = 0
		@save_graph_calls = 0
		@get_graphs_calls = 0
		@get_graph_calls = 0
		@destroy_graph_calls = 0

		@save_context_calls = 0
		@get_contexts_calls = 0
		@get_context_calls = 0
		@destroy_context_calls = 0

		@graphs = {}
		@contexts = {}
		@context_counts = {}
		@graph_count = 0
		super()

	connect: ->
		@connect_calls++
		Q.resolve({})

	getActiveContext: ->
		Q.reject({})

	saveGraph: (graph)->
		@graphs[ @graph_count ] = graph
		graph.id = @graph_count
		@contexts[ @graph_count ] = {}
		@context_counts[ @graph_count ] = 0
		@graph_count++
		@save_graph_calls++
		Q.resolve graph

	getGraphs: ()->
		@get_graphs_calls++
		Q.resolve _.values @graphs

	getGraph: (graph_id)->
		@get_graph_calls++
		Q.resolve @graphs[ graph_id ]

	destroyGraph: (graph_id)->
		delete @graphs[ graph_id ]
		delete @contexts[ graph_id ]
		@destroy_graph_calls++
		Q.resolve({})

	saveContext: (ctx)->
		id = @context_counts[ ctx.graph_id ]
		ctx.id = id
		@context_counts[ ctx.graph_id ]++
		@contexts[ ctx.graph_id ][ id ] = ctx
		@save_context_calls++
		Q.resolve ctx

	destroyContext: (graph_id, ctx_id)->
		delete @contexts[ graph_id ][ ctx_id ]
		@destroy_context_calls++
		Q.resolve({})

	getContexts: (graph_id)->
		@get_contexts_calls++
		Q.resolve _.values @contexts[ graph_id ]

	getContext: (graph_id, context_id)->
		@get_context_calls++
		Q.resolve @contexts[ graph_id ][ context_id ]

	addTrigger: (graph_id, context_id, name, values, source)->
		Q.reject({})

describe 'StateBox', ->
	describe 'Storage', ->
		before (done)->
			@storage = new TestStorage()
			@mgr = new StateBox.Manager( @storage )
			@mgr.init().then ->
				done()

		it 'calls connect', ->
			@storage.connect_calls.should.eql 1

		it 'persists graph', (done)->
			@mgr.buildGraph( '' ).then (graph)=>
				@storage.save_graph_calls.should.eql 1
				@storage.destroy_graph_calls.should.eql 0
				graph.destroy().then =>
					@storage.destroy_graph_calls.should.eql 1
					done()

		it 'destroys graph', (done)->
			@mgr.buildGraph( '' ).then (graph)=>
				@storage.get_graph_calls.should.eql 0
				@mgr.getGraph( graph.id ).then (g1)=>
					@storage.get_graph_calls.should.eql 1
					graph.destroy().then =>
						@mgr.getGraph( graph.id ).then (g2)=>
							@storage.get_graph_calls.should.eql 2
							should.not.exist g2
							should.exist g1
							g1.id.should.eql graph.id
							done()

		it 'fetches graphs', ->
			@storage.get_graphs_calls.should.eql 0
			@mgr.getGraphs().then (graphs)=>
				@storage.get_graphs_calls.should.eql 1
				graphs.should.be.an.instanceOf Array
				graphs.length.should.eql 0

				@mgr.buildGraph( '' ).then (graph)=>
					@mgr.getGraphs().then (graphs)=>
						@storage.get_graphs_calls.should.eql 2
						graphs.should.be.an.instanceOf Array
						graphs.length.should.eql 1
						graphs[ 0 ].id.should.eql graph.id
						done()

		it 'manages contexts', (done)->
			@mgr.buildGraph( '' ).then (graph)=>
				@storage.save_context_calls.should.eql 0
				@storage.get_contexts_calls.should.eql 0
				@storage.get_context_calls.should.eql 0
				@storage.destroy_context_calls.should.eql 0

				@mgr.getContexts( graph.id ).then (ctxs0)=>
					ctxs0.should.be.an.instanceOf Array
					ctxs0.length.should.eql 0
					@storage.get_contexts_calls.should.eql 1

					@mgr.runGraph( graph.id ).then (ctx)=>
						should.exist ctx
						should.exist ctx.id
						@storage.save_context_calls.should.eql 1

						@mgr.getContexts( graph.id ).then (ctxs1)=>
							ctxs1.should.be.an.instanceOf Array
							ctxs1.length.should.eql 1
							ctxs1[ 0 ].id.should.eql ctx.id
							@storage.get_contexts_calls.should.eql 2

							@mgr.getContext( graph.id, ctx.id ).then (ctx1)=>
								should.exist ctx1
								ctx1.id.should.eql ctx.id
								ctx1.graph_id.should.eql graph.id
								@storage.get_context_calls.should.eql 1

								ctx.destroy().then =>
									@storage.destroy_context_calls.should.eql 1

									@mgr.getContexts( graph.id ).then (ctxs2)=>
										ctxs2.should.be.an.instanceOf Array
										ctxs2.length.should.eql 0
										@storage.get_contexts_calls.should.eql 3

										@mgr.getContext( graph.id, ctx.id ).then (ctx2)=>
											should.not.exist ctx2
											@storage.get_context_calls.should.eql 2
											done()
				.fail (r)->
					done(r)

	describe 'Graph', ->
		before (done)->
			@storage = new TestStorage()
			@mgr = new StateBox.Manager( @storage )
			@mgr.init().then ->
				done()

		it 'builds graph', (done)->
			@mgr.buildGraph( '' ).then (graph)->
				should.exist graph
				done()

		it 'graphs have start node', (done)->
			@mgr.buildGraph( '' ).then (graph)=>
				ss = graph.getStartState()
				should.exist ss
				ss.hasFlag( StateBox.State.Flags.Start ).should.eql true
				done()

		#get state
		#parse

	#context
		#current state name
		#choose initial state
		#enters initial state
		#leaves current state
		#enters new state
		#trigger
		#get value
		#set value
		#merge start values

	#State
		#enters
		#leaves
