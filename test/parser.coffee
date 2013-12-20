chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
should = chai.should()
util = require 'util'

Parser = require '../src/graph'

StateBox = require '../lib/statebox'
_ = require 'underscore'
#Q = require 'q'

describe 'Parser', ->
	it 'parses', ->
		s = Parser.parser.parse "state start [start, finish] { @kamil.abc { ? 2+\"ab\\\"c\"-'z'+'a\"b\"c'>3 { kamil; }; !test; } @timer.1 {} }\nstate last {}"
		s.should.be.instanceOf Array
		s.length.should.eql 2
		s[ 0 ].should.be.instanceOf StateBox.State
		s[ 1 ].should.be.instanceOf StateBox.State

	it 'cant access property on invalid object', ->
#		(->Parser.parser.parse "state test { -> { ? a.x { z; } } }").should.throw( "Unknown object: a, use 'ctx' or 'trigger'" )
		(->Parser.parser.parse "state test { -> { ? ctx.x { z; } } }").should.not.throw()

	it 'parses flags', ->
		s = Parser.parser.parse "state s [start] {}"
		s.should.be.instanceOf Array
		s.length.should.eql 1
		s[ 0 ].should.be.instanceOf StateBox.State
		s[ 0 ].flags.should.eql StateBox.State.Flags.Start

		s = Parser.parser.parse "state f [finish] {}"
		s.should.be.instanceOf Array
		s.length.should.eql 1
		s[ 0 ].should.be.instanceOf StateBox.State
		s[ 0 ].flags.should.eql StateBox.State.Flags.Finish

		s = Parser.parser.parse "state fs [finish, start] {}"
		s.should.be.instanceOf Array
		s.length.should.eql 1
		s[ 0 ].should.be.instanceOf StateBox.State
		s[ 0 ].flags.should.eql StateBox.State.Flags.Finish + StateBox.State.Flags.Start

		(->
			Parser.parser.parse "state e [error] {}"
		).should.throw( 'Unknown flag: error' )

	it 'ignores comments', ->
		(-> Parser.parser.parse "state x\nabc\n{}").should.throw()

		s = Parser.parser.parse "state x\n#abc{\n{}"
		s.should.be.instanceOf Array
		s.length.should.eql 1
		s[0].name.should.eql 'x'

		s = Parser.parser.parse "state x\n#a'b'c{\n{}"
		s.should.be.instanceOf Array
		s.length.should.eql 1
		s[0].name.should.eql 'x'

		s = Parser.parser.parse "state x\n#a\"b\"c{\n{}"
		s.should.be.instanceOf Array
		s.length.should.eql 1
		s[0].name.should.eql 'x'

	it 'parses triggers', ->
		s = Parser.parser.parse "state x {}"
		s[0].enterActions.should.eql []
		s[0].leaveActions.should.eql []
		s[0].triggerActions.should.eql []

		s = Parser.parser.parse "state x {->{}}"
		s[0].enterActions.should.eql []
		s[0].leaveActions.should.eql []
		s[0].triggerActions.should.eql []

		s = Parser.parser.parse "state x {<-{}}"
		s[0].enterActions.should.eql []
		s[0].leaveActions.should.eql []
		s[0].triggerActions.should.eql []

		s = Parser.parser.parse "state x {->{a;}}"
		s[0].enterActions.length.should.eql 1
		s[0].enterActions[ 0 ].should.be.instanceOf StateBox.Action.SimpleAction
		s[0].enterActions[ 0 ].name.should.eql 'a'
		s[0].enterActions[ 0 ].args.should.eql []
		s[0].leaveActions.should.eql []
		s[0].triggerActions.should.eql []

		s = Parser.parser.parse "state x {<-{a;}}"
		s[0].enterActions.should.eql []
		s[0].leaveActions.length.should.eql 1
		s[0].leaveActions[ 0 ].should.be.instanceOf StateBox.Action.SimpleAction
		s[0].leaveActions[ 0 ].name.should.eql 'a'
		s[0].leaveActions[ 0 ].args.should.eql []
		s[0].triggerActions.should.eql []

		s = Parser.parser.parse "state x {@t.e.s.t {}}"
		s[0].enterActions.should.eql []
		s[0].leaveActions.should.eql []
		s[0].triggerActions.should.eql [ { at: 't.e.s.t', exe: [], to: undefined } ]

		s = Parser.parser.parse "state x {@t.e.s.t -> y {}}"
		s[0].enterActions.should.eql []
		s[0].leaveActions.should.eql []
		s[0].triggerActions.should.eql [ { at: 't.e.s.t', exe: [], to: 'y' } ]

	it 'parses actions', ->
		s = Parser.parser.parse "state x {-> { a1; !a2; }}"
		s = s[ 0 ].enterActions
		s.should.be.instanceOf Array
		s.length.should.eql 2
		s[ 0 ].should.be.instanceOf StateBox.Action.SimpleAction
		s[ 1 ].should.be.instanceOf StateBox.Action.SimpleAction

		s[ 0 ].name.should.eql 'a1'
		s[ 1 ].name.should.eql 'a2'

		s[ 0 ].args.should.eql []
		s[ 1 ].args.should.eql []

		s[ 0 ].async.should.eql false
		s[ 1 ].async.should.eql true

	it 'parses action parameters', ->
		s = Parser.parser.parse "state x {-> { a1 ctx.a, 2+3, ctx; }}"
		s = s[ 0 ].enterActions[ 0 ]
		s.args.should.be.instanceOf Array
		s.args.length.should.eql 3
		s.args[ 2 ].should.be.instanceOf StateBox.Exp.WordLiteralExp
		s.args[ 2 ].word.should.eql 'ctx'

	it 'parses object literals', ->
		s = Parser.parser.parse "state x {-> { a1 { a: 1, \"b\": 2 }; }}"
		s = s[ 0 ].enterActions[ 0 ]
		s.args.should.be.instanceOf Array
		s.args.length.should.eql 1
		s.args[ 0 ].should.be.instanceOf StateBox.Exp.ObjectLiteralExp
		s.args[ 0 ].props.should.be.instanceOf Array
		s.args[ 0 ].props.length.should.eql 2
		s.args[ 0 ].props[ 0 ][ 0 ].should.eql '"a"'
		s.args[ 0 ].props[ 0 ][ 1 ].should.be.instanceOf StateBox.Exp.NumberLiteralExp
		s.args[ 0 ].props[ 0 ][ 1 ].number.should.eql "1"
		s.args[ 0 ].props[ 1 ][ 0 ].should.eql '"b"'
		s.args[ 0 ].props[ 1 ][ 1 ].should.be.instanceOf StateBox.Exp.NumberLiteralExp
		s.args[ 0 ].props[ 1 ][ 1 ].number.should.eql "2"
