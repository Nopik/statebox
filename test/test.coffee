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
		@update_context_calls = 0
		@get_contexts_calls = 0
		@get_context_calls = 0
		@destroy_context_calls = 0
		@add_trigger_calls = 0

		@process_calls = 0
		@stop_processing_calls = 0
		@is_processing_calls = 0
		@is_stopping_calls = 0

		@graphs = {}
		@contexts = {}
		@context_counts = {}
		@triggers = {}
		@graph_count = 0

		super
			processDelayMs: 10

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

	updateContext: (ctx)->
		@update_context_calls++
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
		@triggers[ graph_id ] ?= {}
		@triggers[ graph_id ][ context_id ] ?= []
		@triggers[ graph_id ][ context_id ].push
			name: name
			values: values
			source: source

		@add_trigger_calls++
		Q.resolve({})

	process: ->
		@process_calls++
		super()

	stopProcessing: (cb)->
		@stop_processing_calls++
		super cb

	isProcessing: ->
		@is_processing_calls++
		super()

	isStopping: ->
		@is_stopping_calls++
		super()

describe 'StateBox', ->
	describe 'Manager', ->
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
								ctx1.status.should.eql StateBox.Context.Status.Active

								@mgr.abortContext( graph.id, ctx.id ).then =>
									@mgr.getContext( graph.id, ctx.id ).then (ctx1a)=>
										ctx1a.status.should.eql StateBox.Context.Status.Aborted

										ctx.destroy().then =>
											@storage.destroy_context_calls.should.eql 1

											@mgr.getContexts( graph.id ).then (ctxs2)=>
												ctxs2.should.be.an.instanceOf Array
												ctxs2.length.should.eql 0
												@storage.get_contexts_calls.should.eql 3

												@mgr.getContext( graph.id, ctx.id ).then (ctx2)=>
													should.not.exist ctx2
													@storage.get_context_calls.should.eql 4

													@storage.update_context_calls.should.eql 1
													done()
				.fail (r)->
					done(r)

		it 'adds trigger', (done)->
			@mgr.buildGraph( '' ).then (graph)=>
				@mgr.runGraph( graph.id ).then (ctx)=>
					@storage.add_trigger_calls.should.eql 0
					@mgr.addTrigger( graph.id, ctx.id, 'test_trigger', { test: 1 }, 'test' ).then =>
						@storage.add_trigger_calls.should.eql 1
						done()

		it 'manages processing', (done)->
			@storage.process_calls.should.eql 0
			@storage.stop_processing_calls.should.eql 0
			@storage.is_processing_calls.should.eql 0
			@storage.is_stopping_calls.should.eql 0

			@mgr.isProcessing().should.eql false
			@mgr.isStopping().should.eql false

			@storage.process_calls.should.eql 0
			@storage.stop_processing_calls.should.eql 0
			@storage.is_processing_calls.should.eql 1
			@storage.is_stopping_calls.should.eql 1

			@mgr.startProcessing().then =>
				@mgr.isProcessing().should.eql true
				@mgr.isStopping().should.eql false

				@storage.process_calls.should.eql 1
				@storage.stop_processing_calls.should.eql 0
				@storage.is_processing_calls.should.eql 2
				@storage.is_stopping_calls.should.eql 2

				@mgr.stopProcessing =>
					@mgr.isProcessing().should.eql false
					@mgr.isStopping().should.eql false

					@storage.process_calls.should.eql 1
					@storage.stop_processing_calls.should.eql 1
					@storage.is_processing_calls.should.eql 3
					@storage.is_stopping_calls.should.eql 3

					done()
			.fail (r)->
				done( r )

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

		it 'allows get state by name', (done)->
			@mgr.buildGraph( '' ).then (graph)=>
				ss = graph.getState( 'start' )
				should.exist ss
				ss.name.should.eql 'start'
				done()

		##parse

	#context
		#choose initial state
		#get value
		#set value
		#merge start values

		##trigger
		##enters initial state
		##enters new state
		##leaves current state

	#State
		##enters
		##leaves
