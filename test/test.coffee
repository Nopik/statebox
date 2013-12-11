chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
should = chai.should()

StateBox = require '../lib/statebox'
_ = require 'underscore'
Q = require 'q'

class TestStorage extends StateBox.Storage
	constructor: ->
		@graphs = {}
		@contexts = {}
		@context_counts = {}
		@triggers = {}
		@graph_count = 0

		super
			processDelayMs: 1

	saveGraph: (graph)->
		@graphs[ @graph_count ] = graph
		graph.id = @graph_count
		@contexts[ @graph_count ] = {}
		@context_counts[ @graph_count ] = 0
		@graph_count++
		Q.resolve graph

	getGraphs: ()->
		Q.resolve _.values @graphs

	getGraph: (graph_id)->
		Q.resolve @graphs[ graph_id ]

	destroyGraph: (graph_id)->
		delete @graphs[ graph_id ]
		delete @contexts[ graph_id ]
		Q.resolve({})

	saveContext: (ctx)->
		id = @context_counts[ ctx.graph_id ]
		ctx.id = id
		@context_counts[ ctx.graph_id ]++
		@contexts[ ctx.graph_id ][ id ] = ctx
		Q.resolve ctx

	destroyContext: (graph_id, ctx_id)->
		delete @contexts[ graph_id ][ ctx_id ]
		Q.resolve({})

	getContexts: (graph_id)->
		Q.resolve _.values @contexts[ graph_id ]

	getContext: (graph_id, context_id)->
		Q.resolve @contexts[ graph_id ][ context_id ]

	addTrigger: (graph_id, context_id, name, values, source)->
		@triggers[ graph_id ] ?= {}
		@triggers[ graph_id ][ context_id ] ?= []
		@triggers[ graph_id ][ context_id ].push
			name: name
			values: values
			source: source

		Q.resolve({})

	getActiveContext: ->
		for gid, graph of @triggers
			for cid, triggers of graph
				trigger = triggers.shift()

				if trigger?
					return Q.resolve
						ctx: @contexts[ gid ][ cid ]
						triggerName: trigger.name
						triggerValues: trigger.values
						source: trigger.source

		Q.reject({})

describe 'StateBox', ->
	describe 'Manager', ->
		beforeEach (done)->
			@storage = new TestStorage()
			@mgr = new StateBox.Manager( @storage )
			@mgr.init().then ->
				done()

		it 'calls connect', (done)->
			storage = new TestStorage()
			mgr = new StateBox.Manager( storage )
			spy = sinon.spy( storage, 'connect' )
			mgr.init().then ->
				spy.should.have.been.calledOnce.calledWithExactly()
				done()
			.fail (r)->
				done( r )

		it 'persists graph', (done)->
			saveSpy = sinon.spy @storage, 'saveGraph'
			destroySpy = sinon.spy @storage, 'destroyGraph'
			@mgr.buildGraph( 'state a {}' ).then (graph)=>
				id = graph.id
				graph.destroy().then =>
					destroySpy.should.have.been.calledOnce.calledWithExactly( id )
					done()
			.fail (r)->
				done( r )

		it 'destroys graph', (done)->
			@mgr.buildGraph( 'state a[start] {}' ).then (graph)=>
				getSpy = sinon.spy @storage, 'getGraph'
				id = graph.id
				@mgr.getGraph( id ).then (g1)=>
					graph.destroy().then =>
						@mgr.getGraph( id ).then (g2)=>
							getSpy.should.have.been.calledTwice.always.calledWithExactly( id )
							should.not.exist g2
							should.exist g1
							g1.id.should.eql id
							done()
			.fail (r)->
				done( r )

		it 'fetches graphs', ->
			getSpy = sinon.spy @storage, 'getGraphs'
			@mgr.getGraphs().then (graphs)=>
				graphs.should.be.an.instanceOf Array
				graphs.length.should.eql 0

				@mgr.buildGraph( 'state a[start] {}' ).then (graph)=>
					@mgr.getGraphs().then (graphs)=>
						getSpy.should.have.been.calledTwice.always.calledWithExactly()
						graphs.should.be.an.instanceOf Array
						graphs.length.should.eql 1
						graphs[ 0 ].id.should.eql graph.id
						done()

		it 'manages contexts', (done)->
			getContextSpy = sinon.spy @storage, 'getContext'
			saveContextSpy = sinon.spy @storage, 'saveContext'
			destroyContextSpy = sinon.spy @storage, 'destroyContext'
			getContextsSpy = sinon.spy @storage, 'getContexts'
			updateContextSpy = sinon.spy @storage, 'updateContext'

			@mgr.buildGraph( 'state a[start] {}' ).then (graph)=>
				@mgr.getContexts( graph.id ).then (ctxs0)=>
					ctxs0.should.be.an.instanceOf Array
					ctxs0.length.should.eql 0

					@mgr.runGraph( graph.id ).then (ctx)=>
						should.exist ctx
						should.exist ctx.id

						@mgr.getContexts( graph.id ).then (ctxs1)=>
							ctxs1.should.be.an.instanceOf Array
							ctxs1.length.should.eql 1
							ctxs1[ 0 ].id.should.eql ctx.id

							@mgr.getContext( graph.id, ctx.id ).then (ctx1)=>
								should.exist ctx1
								ctx1.id.should.eql ctx.id
								ctx1.graph_id.should.eql graph.id
								ctx1.status.should.eql StateBox.Context.Status.Active

								@mgr.abortContext( graph.id, ctx.id ).then =>
									@mgr.getContext( graph.id, ctx.id ).then (ctx1a)=>
										ctx1a.status.should.eql StateBox.Context.Status.Aborted

										ctx.destroy().then =>
											@mgr.getContexts( graph.id ).then (ctxs2)=>
												ctxs2.should.be.an.instanceOf Array
												ctxs2.length.should.eql 0

												getContextSpy.should.have.been.calledThrice.always.calledWithExactly graph.id, ctx.id
												getContextSpy.reset()

												@mgr.getContext( graph.id, ctx.id ).then (ctx2)=>
													should.not.exist ctx2

													getContextSpy.should.have.been.calledOnce.calledWithExactly graph.id, ctx.id
													saveContextSpy.should.have.been.calledOnce.calledWithExactly ctx
													destroyContextSpy.should.have.been.calledOnce.calledWithExactly( graph.id, ctx.id )
													updateContextSpy.should.have.been.calledOnce.calledWithExactly ctx
													getContextsSpy.should.have.been.calledThrice.always.calledWithExactly graph.id

													done()
			.fail (r)->
				done(r)

		it 'adds trigger', (done)->
			addSpy = sinon.spy @storage, 'addTrigger'

			@mgr.buildGraph( 'state a[start] {}' ).then (graph)=>
				@mgr.runGraph( graph.id ).then (ctx)=>
					@mgr.addTrigger( graph.id, ctx.id, 'test_trigger', { test: 1 }, 'test' ).then =>
						addSpy.should.have.been.calledOnce.calledWithExactly graph.id, ctx.id, 'test_trigger', { test: 1 }, 'test'
						done()
			.fail (r)->
				done( r )

		it 'manages processing', (done)->
			processSpy = sinon.spy @storage, 'process'
			stopProcessingSpy = sinon.spy @storage, 'stopProcessing'
			isProcessingSpy = sinon.spy @storage, 'isProcessing'
			isStoppingSpy = sinon.spy @storage, 'isStopping'

			@mgr.isProcessing().should.eql false
			@mgr.isStopping().should.eql false

			@mgr.startProcessing().then =>
				@mgr.isProcessing().should.eql true
				@mgr.isStopping().should.eql false

				f = =>
					@mgr.isProcessing().should.eql false
					@mgr.isStopping().should.eql false

					processSpy.should.have.been.calledOnce.calledWithExactly()
					stopProcessingSpy.should.have.been.calledOnce.calledWithExactly( f )
					isProcessingSpy.should.have.been.calledThrice.always.calledWithExactly()
					isStoppingSpy.should.have.been.calledThrice.always.calledWithExactly()

					done()

				@mgr.stopProcessing f
			.fail (r)->
				done( r )

		describe 'Processing', ->
			beforeEach (done)->
				@mgr.buildGraph( 'state a[start] { @test.name {}; @b -> b; }; state b { @a -> a; };' ).then (graph)=>
					@graph = graph

					@mgr.runGraph( @graph.id ).then (ctx)=>
						@ctx = ctx

						@mgr.startProcessing().then ->
							done()
				.fail (r)->
					done( r )

			afterEach (done)->
				@mgr.stopProcessing ->
					done()

			it 'performs processing', (done)->
				handleSpy = sinon.spy @storage, 'handleContext'
				ctxSpy = sinon.spy @ctx, 'trigger'

				tName = 'test.name'
				tVals =
					foo: 42

				processed = (ctx, triggerName)=>
					try
						ctx.should.eql @ctx
						triggerName.should.eql tName
						handleSpy.should.have.been.calledOnce.calledWithExactly( @ctx, tName, tVals )
						ctxSpy.should.have.been.calledOnce.calledWithExactly( tName, tVals )
						done()
					catch e
						done( e )

				@storage.on 'processedTrigger', processed

				@mgr.addTrigger( @graph.id, @ctx.id, tName, tVals, 'test source' ).then =>
					true
				.fail (r)->
					done( r )

			it 'changes states', (done)->
				step = 0

				@storage.on 'processedTrigger', (ctx, name)=>
					if step == 0
						name.should.eql 'b'
						@ctx.getValue( StateBox.Context.StateValueName ).name.should.eql 'b'
						step = 1
						@mgr.addTrigger( @graph.id, @ctx.id, 'a', {}, '' ).then =>
							true
					else
						if step == 1
							@ctx.getValue( StateBox.Context.StateValueName ).name.should.eql 'a'
							done()

				@mgr.addTrigger( @graph.id, @ctx.id, 'b', {}, '' ).then =>
					true

	describe 'Graph', ->
		beforeEach (done)->
			@storage = new TestStorage()
			@mgr = new StateBox.Manager( @storage )
			@mgr.init().then ->
				done()

		it 'builds graph', (done)->
			@mgr.buildGraph( 'state a[start] {}' ).then (graph)->
				should.exist graph
				done()

		it 'graphs have start node', (done)->
			@mgr.buildGraph( 'state a[start] {}' ).then (graph)=>
				ss = graph.getStartState()
				should.exist ss
				ss.hasFlag( StateBox.State.Flags.Start ).should.eql true
				done()

		it 'allows get state by name', (done)->
			@mgr.buildGraph( 'state foo[start] {}' ).then (graph)=>
				ss = graph.getState( 'foo' )
				should.exist ss
				ss.name.should.eql 'foo'
				done()

	describe 'Context', ->
		beforeEach (done)->
			@storage = new TestStorage()
			@mgr = new StateBox.Manager( @storage )
			@mgr.init().then =>
				@mgr.buildGraph( 'state a[start] { @b -> b; } state b { @a -> a; }' ).then (graph)=>
					@graph = graph

					@mgr.runGraph( graph.id, { foo: 42 } ).then (ctx)=>
						@ctx = ctx
						done()
			.fail (r)->
				done( r )

		it 'chooses initial state', ->
			ss = @graph.getStartState()
			should.exist ss
			@ctx.getValue( StateBox.Context.StateValueName ).should.eql ss

		it 'sets values', ->
			v = 'test_val'
			n = 'test name'

			should.not.exist @ctx.getValue( n )
			@ctx.setValue n, v
			@ctx.getValue( n ).should.eql v

		it 'merges initial values', ->
			@ctx.getValue( 'foo' ).should.eql 42

		##enters initial state
		##enters new state
		##leaves current state
		##trigger moves

	class TestAction extends StateBox.Action.SimpleAction

	describe 'State', ->
		beforeEach ->
			@enterActions = [
				new TestAction()
				new TestAction()
				new TestAction()
			]
			@leaveActions = [
				new TestAction()
				new TestAction()
				new TestAction()
			]
			@state = new StateBox.State( 'test', @enterActions, @leaveActions )

			@enterSpies = _.collect @enterActions, (ea)->
				sinon.spy ea, 'execute'

			@leaveSpies = _.collect @leaveActions, (ea)->
				sinon.spy ea, 'execute'

		it 'launches enter actions', (done)->
			ctx = {}
			vals = { foo: 42 }

			@state.enter( ctx, vals ).then =>
				_.each @enterSpies, (spy)->
					spy.should.have.been.calledOnce.calledWithExactly( ctx, vals )

				_.each @leaveSpies, (spy)->
					spy.should.not.have.been.called

				done()
			.fail (r)->
				done( r )

		it 'launches leave actions', (done)->
			ctx = {}
			vals = { foo: 42 }

			@state.leave( ctx, vals ).then =>
				_.each @leaveSpies, (spy)->
					spy.should.have.been.calledOnce.calledWithExactly( ctx, vals )

				_.each @enterSpies, (spy)->
					spy.should.not.have.been.called

				done()
			.fail (r)->
				done( r )
