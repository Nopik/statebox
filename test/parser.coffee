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
		console.log Parser.parser.parse "state [start, finish] { @kamil.abc { ? 2+\"ab\\\"c\"-'z'+'a\"b\"c'>3 kamil; !test; } @timer.1 {} }\nstate {}"
