chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
should = chai.should()

Parser = require '../src/graph'

StateBox = require '../lib/statebox'
_ = require 'underscore'
#Q = require 'q'

describe 'Parser', ->
	it 'parses', ->
		s = Parser.parser.parse "state start [start, finish] { @kamil.abc { ? 2+\"ab\\\"c\"-'z'+'a\"b\"c'>3 kamil; !test; } @timer.1 {} }\nstate last {}"
		s.should.be.instanceOf Array
		s.length.should.eql 2
		s[ 0 ].should.be.instanceOf StateBox.State
		s[ 1 ].should.be.instanceOf StateBox.State

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
