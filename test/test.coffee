should = require 'should'
StateBox = require '../lib/statebox'
_ = require 'underscore'

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

	saveGraph: (graph)->
		@graphs[ @graph_count ] = graph
		graph.id = @graph_count
		@contexts[ @graph_count ] = {}
		@context_counts[ @graph_count ] = 0
		@graph_count++
		@save_graph_calls++

	getGraphs: ()->
		@get_graphs_calls++
		_.values @graphs

	getGraph: (graph_id)->
		@get_graph_calls++
		@graphs[ graph_id ]

	destroyGraph: (graph_id)->
		delete @graphs[ graph_id ]
		delete @contexts[ graph_id ]
		@destroy_graph_calls++

	saveContext: (ctx)->
		id = @context_counts[ ctx.graph_id ]
		ctx.id = id
		@context_counts[ ctx.graph_id ]++
		@contexts[ ctx.graph_id ][ id ] = ctx
		@save_context_calls++
		ctx

	destroyContext: (graph_id, ctx_id)->
		delete @contexts[ graph_id ][ ctx_id ]
		@destroy_context_calls++

	getContexts: (graph_id)->
		@get_contexts_calls++
		_.values @contexts[ graph_id ]

	getContext: (graph_id, context_id)->
		@get_context_calls++
		@contexts[ graph_id ][ context_id ]

describe 'StateBox', ->
	describe 'Storage', ->
		before ->
			@storage = new TestStorage()
			@mgr = new StateBox.Manager( @storage )

		it 'calls connect', ->
			@storage.connect_calls.should.eql 1

		it 'persists graph', ->
			graph = @mgr.buildGraph( '' )
			@storage.save_graph_calls.should.eql 1
			@storage.destroy_graph_calls.should.eql 0
			graph.destroy()
			@storage.destroy_graph_calls.should.eql 1

		it 'destroys graph', ->
			graph = @mgr.buildGraph( '' )
			@storage.get_graph_calls.should.eql 0
			g1 = @mgr.getGraph( graph.id )
			@storage.get_graph_calls.should.eql 1
			graph.destroy()
			g2 = @mgr.getGraph( graph.id )
			@storage.get_graph_calls.should.eql 2
			should.not.exist g2
			should.exist g1
			g1.id.should.eql graph.id

		it 'fetches graphs', ->
			@storage.get_graphs_calls.should.eql 0
			graphs = @mgr.getGraphs()
			@storage.get_graphs_calls.should.eql 1
			graphs.should.be.an.instanceOf Array
			graphs.length.should.eql 0

			graph = @mgr.buildGraph( '' )

			graphs = @mgr.getGraphs()
			@storage.get_graphs_calls.should.eql 2
			graphs.should.be.an.instanceOf Array
			graphs.length.should.eql 1
			graphs[ 0 ].id.should.eql graph.id

		it 'manages contexts', ->
			graph = @mgr.buildGraph( '' )

			@storage.save_context_calls.should.eql 0
			@storage.get_contexts_calls.should.eql 0
			@storage.get_context_calls.should.eql 0
			@storage.destroy_context_calls.should.eql 0

			ctxs0 = @mgr.getContexts( graph.id )
			ctxs0.should.be.an.instanceOf Array
			ctxs0.length.should.eql 0
			@storage.get_contexts_calls.should.eql 1

			ctx = @mgr.runGraph( graph.id )
			should.exist ctx
			should.exist ctx.id
			@storage.save_context_calls.should.eql 1

			ctxs1 = @mgr.getContexts( graph.id )
			ctxs1.should.be.an.instanceOf Array
			ctxs1.length.should.eql 1
			ctxs1[ 0 ].id.should.eql ctx.id
			@storage.get_contexts_calls.should.eql 2

			ctx1 = @mgr.getContext( graph.id, ctx.id )
			should.exist ctx1
			ctx1.id.should.eql ctx.id
			ctx1.graph_id.should.eql graph.id
			@storage.get_context_calls.should.eql 1

			ctx.destroy()
			@storage.destroy_context_calls.should.eql 1

			ctxs2 = @mgr.getContexts( graph.id )
			ctxs2.should.be.an.instanceOf Array
			ctxs2.length.should.eql 0
			@storage.get_contexts_calls.should.eql 3

			ctx2 = @mgr.getContext( graph.id, ctx.id )
			should.not.exist ctx2
			@storage.get_context_calls.should.eql 2

	describe 'Graph', ->
		before ->
			@storage = new TestStorage()
			@mgr = new StateBox.Manager( @storage )

		it 'builds graph', ->
			graph = @mgr.buildGraph( '' )
			should.exist graph

		it 'graphs have start node', ->
			graph = @mgr.buildGraph( '' )
			ss = graph.getStartState()
			should.exist ss
			ss.hasFlag( StateBox.State.Flags.Start ).should.eql true

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
