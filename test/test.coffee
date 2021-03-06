chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
should = chai.should()
util = require 'util'
utils = require '../lib/utils'
nock = require 'nock'

StateBox = require '../lib/statebox'
_ = require 'underscore'
Q = require 'q'
SpecHelpers = require './spec_helpers'

class TestStorage extends StateBox.Storage
	constructor: ->
		@graphs = {}
		@contexts = {}
		@context_counts = {}
		@triggers = {}
		@graph_count = 0

		super
			processDelayMs: 1

		@actions =
			test: new SpecHelpers.TestActionRunner()

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

	addTrigger: (graph_id, context_id, name, values)->
		@triggers[ graph_id ] ?= {}
		@triggers[ graph_id ][ context_id ] ?= []
		@triggers[ graph_id ][ context_id ].push
			name: name
			values: values

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

		Q.reject({})

	abortContext: ->
		Q.resolve {}

describe 'StateBox', ->
	describe 'Manager', ->
		beforeEach (done)->
			@storage = new TestStorage()
			@storage.setActions SpecHelpers.actions
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
					saveSpy.should.have.been.calledOnce
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
													getContextsSpy.should.have.been.calledThrice.always.calledWithExactly graph.id

													done()
			.fail (r)->
				done(r)

		it 'adds trigger', (done)->
			addSpy = sinon.spy @storage, 'addTrigger'

			@mgr.buildGraph( 'state a[start] {}' ).then (graph)=>
				@mgr.runGraph( graph.id ).then (ctx)=>
					@mgr.addTrigger( graph.id, ctx.id, 'test_trigger', { test: 1 } ).then =>
						addSpy.should.have.been.calledOnce.calledWithExactly graph.id, ctx.id, 'test_trigger', { test: 1 }
						done()
			.fail (r)->
				done( r )

#		it 'sets context values', (done)->
#			@mgr.buildGraph( 'state a[start] {}' ).then (graph)=>
#				@mgr.runGraph( graph.id ).then (ctx)=>
#					@mgr.getContextValue( graph.id, ctx.id, 'foo' ).then (v)=>
#						should.not.exist v
#
#						@mgr.setContextValue( graph.id, ctx.id, 'foo', 42 ).then =>
#							@mgr.getContextValue( graph.id, ctx.id, 'foo' ).then (v)=>
#								should.exist v
#								v.should.eql 42
#
#								done()
#			.fail (r)->
#				done( r )

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
				source = """
					state a[start]
					{
						-> { s1; };

						<- { s2; };

						@test.name {};

						@b -> b { a1; };
					};

					state b
					{
						-> { s3; };

						<- { s4; };

						@a -> a { a2; };
					};
"""

				@mgr.buildGraph( source ).then (graph)=>
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
				ctxSpy = sinon.spy @ctx, 'processTrigger'

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

				@mgr.addTrigger( @graph.id, @ctx.id, tName, tVals ).then =>
					true
				.fail (r)->
					done( r )

			it 'changes states', (done)->
				step = 0
				vals = { bar: 42 }
				valsh = new StateBox.Values.Holder vals

				aSpy = sinon.spy @graph.getState( 'a' ).findTriggerAction( 'b' ).exe[ 0 ], 'execute'
				bSpy = sinon.spy @graph.getState( 'b' ).findTriggerAction( 'a' ).exe[ 0 ], 'execute'

				aeSpy = sinon.spy @graph.getState( 'a' ).enterActions[0], 'execute'
				alSpy = sinon.spy @graph.getState( 'a' ).leaveActions[0], 'execute'
				beSpy = sinon.spy @graph.getState( 'b' ).enterActions[0], 'execute'
				blSpy = sinon.spy @graph.getState( 'b' ).leaveActions[0], 'execute'

				@storage.on 'processedTrigger', (ctx, name)=>
					try
						if step == 0
							aeSpy.should.have.not.been.called
							alSpy.should.have.been.calledOnce.calledWithExactly( @ctx, valsh )
							beSpy.should.have.been.calledOnce.calledWithExactly( @ctx, valsh )
							blSpy.should.have.not.been.called

							name.should.eql 'b'
							@ctx.getValue( StateBox.Context.StateValueName ).should.eql 'b'
							step = 1
							@mgr.addTrigger( @graph.id, @ctx.id, 'a', vals ).then =>
								true
						else
							if step == 1
								aSpy.should.have.been.calledOnce.calledWithExactly( @ctx, valsh )
								bSpy.should.have.been.calledOnce.calledWithExactly( @ctx, valsh )

								aeSpy.should.have.been.calledOnce.calledWithExactly( @ctx, valsh )
								alSpy.should.have.been.calledOnce.calledWithExactly( @ctx, valsh )
								beSpy.should.have.been.calledOnce.calledWithExactly( @ctx, valsh )
								blSpy.should.have.been.calledOnce.calledWithExactly( @ctx, valsh )

								@ctx.getValue( StateBox.Context.StateValueName ).should.eql 'a'
								done()
					catch e
						step = -1
						done( e )

				@mgr.addTrigger( @graph.id, @ctx.id, 'b', vals ).then =>
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
				@mgr.buildGraph( 'state a[start] {}' ).then (graph)=>
					@graph = graph

					@mgr.runGraph( graph.id, { foo: 42 } ).then (ctx)=>
						@ctx = ctx
						done()
			.fail (r)->
				done( r )

		it 'chooses initial state', ->
			ss = @graph.getStartState()
			should.exist ss
			@ctx.getValue( StateBox.Context.StateValueName ).should.eql ss.name

		it 'sets values', ->
			v = 'test_val'
			n = 'test name'

			should.not.exist @ctx.getValue( n )
			@ctx.setValue n, v
			@ctx.getValue( n ).should.eql v

		it 'merges initial values', ->
			@ctx.getValue( 'foo' ).should.eql 42

	describe 'State', ->
		beforeEach ->
			@enterActions = [
				new SpecHelpers.TestAction()
				new SpecHelpers.TestAction()
				new SpecHelpers.TestAction()
			]
			@leaveActions = [
				new SpecHelpers.TestAction()
				new SpecHelpers.TestAction()
				new SpecHelpers.TestAction()
			]
			@state = new StateBox.State( 'test', @enterActions, @leaveActions )

			@enterSpies = _.collect @enterActions, (ea)->
				sinon.spy ea, 'execute'

			@leaveSpies = _.collect @leaveActions, (ea)->
				sinon.spy ea, 'execute'

		it 'launches enter actions', (done)->
			ctx = { getActions: -> SpecHelpers.actions }
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
			ctx = { getActions: -> SpecHelpers.actions }
			vals = { foo: 42 }

			@state.leave( ctx, vals ).then =>
				_.each @leaveSpies, (spy)->
					spy.should.have.been.calledOnce.calledWithExactly( ctx, vals )

				_.each @enterSpies, (spy)->
					spy.should.not.have.been.called

				done()
			.fail (r)->
				done( r )

	describe 'Action', ->
		beforeEach (done)->
			@storage = new TestStorage()
			@storage.setActions
				a1: new SpecHelpers.TestActionRunner()
				a2a: new SpecHelpers.TestActionRunner()
				a2b: new SpecHelpers.TestActionRunner()
				a3: new SpecHelpers.TestActionRunner()
				a4: new SpecHelpers.TestActionRunner()
				a5: new SpecHelpers.TestActionRunner()
				f42: new SpecHelpers.TestActionRunner( 42 )

			@mgr = new StateBox.Manager( @storage )
			@mgr.init().then =>
				source = """
					state a[start]
					{
						@a {
							a1;
							? (2+3 > 4) && (5 > -5) {
								a2a;
							}

							? (2+3 > 5) && (5 > -5) {
								a2b;
							}

							? trigger.foo + ctx.bar == 50 {
								a3;
							}

							? trigger.bar[ 0 ] == "baz" {
								a4;
							}

							? exist( trigger.qux ) == true {
								a5;
							}

							= ctx.quuz = 17;
							= ctx.quuz += 25;
							= ctx.corge = action.f42();
							= ctx.grault = { a: 1, "b": 2, c: 6*7 };
						}
					}
"""

				@mgr.buildGraph( source ).then (graph)=>
					@graph = graph

					@mgr.runGraph( graph.id, { bar: 8 } ).then (ctx)=>
						@ctx = ctx

						@mgr.startProcessing().then ->
							done()
			.fail (r)->
				done( r )

		afterEach (done)->
			@mgr.stopProcessing ->
				done()

		it 'gets called', (done)->
			vals1 =
				foo: 42
				bar: [ 'baz' ]
				qux: true

			vals2 =
				foo: 1
				bar: [ 'bazz' ]

			vals1h = new StateBox.Values.Holder vals1
			vals2h = new StateBox.Values.Holder vals2

			a1Spy = sinon.spy @graph.states[0].triggerActions[0].exe[ 0 ], 'execute'
			a20Spy = sinon.spy @graph.states[0].triggerActions[0].exe[ 1 ], 'execute'
			a21Spy = sinon.spy @graph.states[0].triggerActions[0].exe[ 1 ].actions[ 0 ], 'execute'
			a22Spy = sinon.spy @graph.states[0].triggerActions[0].exe[ 2 ], 'execute'
			a23Spy = sinon.spy @graph.states[0].triggerActions[0].exe[ 2 ].actions[ 0 ], 'execute'
			a30Spy = sinon.spy @graph.states[0].triggerActions[0].exe[ 3 ], 'execute'
			a31Spy = sinon.spy @graph.states[0].triggerActions[0].exe[ 3 ].actions[ 0 ], 'execute'
			a40Spy = sinon.spy @graph.states[0].triggerActions[0].exe[ 4 ], 'execute'
			a41Spy = sinon.spy @graph.states[0].triggerActions[0].exe[ 4 ].actions[ 0 ], 'execute'
			a50Spy = sinon.spy @graph.states[0].triggerActions[0].exe[ 5 ], 'execute'
			a51Spy = sinon.spy @graph.states[0].triggerActions[0].exe[ 5 ].actions[ 0 ], 'execute'
			a6Spy = sinon.spy @graph.states[0].triggerActions[0].exe[ 6 ], 'execute'
			a7Spy = sinon.spy @graph.states[0].triggerActions[0].exe[ 7 ], 'execute'

			fs = [
				(ctx, name)=>
					a1Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals1h )
					a20Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals1h )
					a21Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals1h )
					a22Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals1h )
					a23Spy.should.have.not.been.called
					a30Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals1h )
					a31Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals1h )
					a40Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals1h )
					a41Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals1h )
					a50Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals1h )
					a51Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals1h )
					a6Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals1h )
					a7Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals1h )

					v = ctx.getValue( 'quuz' )
					should.exist v
					v.should.eql 42

					v = ctx.getValue( 'corge' )
					should.exist v
					v.should.eql 42

					v = ctx.getValue( 'grault' )
					should.exist v
					v.should.eql
						a: 1
						b: 2
						c: 42

					a1Spy.reset()
					a20Spy.reset()
					a21Spy.reset()
					a22Spy.reset()
					a23Spy.reset()
					a30Spy.reset()
					a31Spy.reset()
					a40Spy.reset()
					a41Spy.reset()
					a50Spy.reset()
					a51Spy.reset()
					a6Spy.reset()
					a7Spy.reset()

				(ctx, name)=>
					a1Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals2h )
					a20Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals2h )
					a21Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals2h )
					a22Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals2h )
					a23Spy.should.have.not.been.called
					a30Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals2h )
					a31Spy.should.have.not.been.called
					a40Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals2h )
					a41Spy.should.have.not.been.called
					a50Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals2h )
					a51Spy.should.have.not.been.called
					a6Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals2h )
					a7Spy.should.have.been.calledOnce.calledWithExactly( @ctx, vals2h )
			]

			SpecHelpers.waitForTriggers @storage, fs, done

			SpecHelpers.sendTriggers @mgr, @graph.id, @ctx.id, [
				[ 'a', vals1 ]
				[ 'a', vals2 ]
			]

	describe 'Runners', ->
		beforeEach (done)->
			@storage = new TestStorage()
			@storage.setActions
				http: new StateBox.Runners.Http()
				getJSON: new StateBox.Runners.Json()
				amqp: new StateBox.Runners.Amqp()

			@mgr = new StateBox.Manager( @storage )
			@mgr.init().then =>
				source = """
					state a[start]
					{
						@a {
							= ctx.res = action.http( "http://"+trigger.host+":"+trigger.port+trigger.path );
							= ctx.baz = action.getJSON( "http://"+trigger.host+":"+trigger.port+trigger.path+"2" );
						}

						@b {
							= ctx.qux = action.amqp( "amqp://" + trigger.host, trigger.exchange, trigger.routing_key, { val: 'some'} );
						}
					}
"""
				@mgr.buildGraph( source ).then (graph)=>
					@graph = graph

					@mgr.runGraph( graph.id, {} ).then (ctx)=>
						@ctx = ctx

						@mgr.startProcessing().then ->
							done()
			.fail (r)->
				done( r )

		afterEach (done)->
			@mgr.stopProcessing ->
				done()

		it 'calls http', (done)->
			testval =
				foo: 'bar'

			nock.disableNetConnect()
			nock( 'http://localhost:7000' ).get( '/http_test' ).reply( 200, '42', {'Content-Type': 'text/plain'} )
			nock( 'http://localhost:7000' ).get( '/http_test2' ).reply( 200, testval, {'Content-Type': 'application/json'} )

			vals =
				host: 'localhost'
				port: 7000
				path: '/http_test'

			fs = [
				(ctx, name)=>
					v = ctx.getValue( 'res' )
					should.exist v
					v.should.eql '42'

					v = ctx.getValue( 'baz' )
					should.exist v
					v.should.eql testval
			]

			SpecHelpers.waitForTriggers @storage, fs, done

			SpecHelpers.sendTriggers @mgr, @graph.id, @ctx.id, [
				[ 'a', vals ]
			]

		it 'call amqp', (done)->
			fake_invoke = (ctx, args) ->
				"#{args[0]},#{args[1]},#{args[2]}"

			@storage.actions.amqp.invoke = fake_invoke

			vals =
				host: 'localhost'
				exchange: 'some_exchange'
				routing_key: 'some_key'

			fs = [
				(ctx, name)=>
					v = ctx.getValue( 'qux' )
					should.exist v
					v.should.eql "amqp://localhost,some_exchange,some_key"
			]

			SpecHelpers.waitForTriggers @storage, fs, done

			SpecHelpers.sendTriggers @mgr, @graph.id, @ctx.id, [
				[ 'b', vals ]
			]
