class AssignmentExp
	constructor: (@left, @op, @right)->

class OpExp
	constructor: (@left, @op, @right)->

class UnaryOpExp
	constructor: (@op, @right)->

class NumberLiteralExp
	constructor: (@number)->

class StringLiteralExp
	constructor: (@string)->

class WordLiteralExp
	constructor: (@word)->

class SubscriptExp
	constructor: (@base, @subscript)->

class CallExp
	constructor: (@base, @args)->

class PropExp
	constructor: (@base, @prop)->

module.exports =
	AssignmentExp: AssignmentExp
	OpExp: OpExp
	UnaryOpExp: UnaryOpExp
	NumberLiteralExp: NumberLiteralExp
	StringLiteralExp: StringLiteralExp
	WordLiteralExp: WordLiteralExp
	SubscriptExp: SubscriptExp
	CallExp: CallExp
	PropExp: PropExp
