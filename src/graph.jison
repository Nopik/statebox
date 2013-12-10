%{
StateBox = require('../lib/statebox');
ParseHelpers = require('./parse_helpers');
%}

%lex

%%

\s+ {}
\"(\\.|[^"])*\" { return 'STRING_LITERAL'; }
\'(\\.|[^'])*\' { return 'STRING_LITERAL'; }
'[' { return '['; }
']' { return ']'; }
'(' { return '('; }
')' { return ')'; }
'{' { return '{'; }
'}' { return '}'; }
'<' { return '<'; }
'>' { return '>'; }
'<=' { return 'LE_OP'; }
'>=' { return 'GE_OP'; }
'==' { return 'EQ_OP'; }
'!=' { return 'NE_OP'; }
',' { return ','; }
';' { return ';'; }
'.' { return '.'; }
'&' { return '&'; }
'|' { return '|'; }
'^' { return '^'; }
'*' { return '*'; }
'/' { return '/'; }
'%' { return '%'; }
'+' { return '+'; }
'-' { return '-'; }
'~' { return '~'; }
'!' { return '!'; }
'?' { return '?'; }
'++' { return 'INC_OP'; }
'--' { return 'DEC_OP'; }
'&&' { return 'AND_OP'; }
'||' { return 'OR_OP'; }
'->' { return 'TRIG_IN'; }
'<-' { return 'TRIG_OUT'; }
'@' { return 'TRIG_AT'; }
'<<' { return 'LEFT_OP'; }
'>>' { return 'RIGHT_OP'; }
'*=' { return 'MUL_ASSIGN'; }
'/=' { return 'DIV_ASSIGN'; }
'%=' { return 'MOD_ASSIGN'; }
'+=' { return 'ADD_ASSIGN'; }
'-=' { return 'SUB_ASSIGN'; }
'<<=' { return 'LEFT_ASSIGN'; }
'>>=' { return 'RIGHT_ASSIGN'; }
'&=' { return 'AND_ASSIGN'; }
'^=' { return 'XOR_ASSIGN'; }
'|=' { return 'OR_ASSIGN'; }

'state' { return 'STATE'; }
'action' { return 'ACTION'; }
\w+ { return 'WORD'; }

[0-9]+ { return 'NUMBER'; }

/lex

%start graph

%%

graph
	: states { return $1; };

states
	: state { $$ = [ $1 ]; }
	| states state { $$ = $1.concat( [ $2 ] ); };

state : STATE WORD state_flags '{' triggers '}' opt_semi { $$ = new StateBox.State( $2, [], [], $3 ) };

state_flags : { $$ = 0; } | '[' flags ']' { $$ = $2; };

flags : WORD { $$ = ParseHelpers.getFlag( $1 ); } | flags ',' WORD { $$ = $1 + ParseHelpers.getFlag( $3 ); };

triggers
	: { $$ = []; }
	| triggers trigger { $$ = $1.concat( [ $2 ] ); };

trigger
	: TRIG_IN '{' actions '}'
	| TRIG_OUT '{' actions '}'
	| TRIG_AT identifier '{' actions '}';

actions
	: { $$ = []; }
	| actions full_action ';' { $$ = $1.concat( [ $2 ] ); };

opt_semi : | ';';

identifier
	: WORD { $$ = [ $1 ]; }
	| identifier '.' WORD { $$ = $1.concat( [ $3 ] ) };

full_action
	: conditional action
	| action;

conditional
	: '?' logical_or_expression;

action
	: async_specifier WORD
	| async_specifier WORD argument_expression_list;

async_specifier
	: { $$ = false; }
	| '!' { $$ = true; };

primary_expression
	: WORD
	| NUMBER
	| STRING_LITERAL
	| '(' expression ')'
	;

postfix_expression
	: primary_expression
	| postfix_expression '[' expression ']'
	| postfix_expression '(' ')'
	| postfix_expression '(' argument_expression_list ')'
	| postfix_expression '.' WORD
	| postfix_expression INC_OP
	| postfix_expression DEC_OP
	;

argument_expression_list
	: logical_or_expression
	| argument_expression_list ',' logical_or_expression
	;

unary_expression
	: postfix_expression
	| INC_OP unary_expression
	| DEC_OP unary_expression
	| unary_operator unary_expression
	;

unary_operator
	: '&'
	| '*'
	| '+'
	| '-'
	| '~'
	| '!'
	;

multiplicative_expression
	: unary_expression
	| multiplicative_expression '*' unary_expression
	| multiplicative_expression '/' unary_expression
	| multiplicative_expression '%' unary_expression
	;

additive_expression
	: multiplicative_expression
	| additive_expression '+' multiplicative_expression
	| additive_expression '-' multiplicative_expression
	;

shift_expression
	: additive_expression
	| shift_expression LEFT_OP additive_expression
	| shift_expression RIGHT_OP additive_expression
	;

relational_expression
	: shift_expression
	| relational_expression '<' shift_expression
	| relational_expression '>' shift_expression
	| relational_expression LE_OP shift_expression
	| relational_expression GE_OP shift_expression
	;

equality_expression
	: relational_expression
	| equality_expression EQ_OP relational_expression
	| equality_expression NE_OP relational_expression
	;

and_expression
	: equality_expression
	| and_expression '&' equality_expression
	;

exclusive_or_expression
	: and_expression
	| exclusive_or_expression '^' and_expression
	;

inclusive_or_expression
	: exclusive_or_expression
	| inclusive_or_expression '|' exclusive_or_expression
	;

logical_and_expression
	: inclusive_or_expression
	| logical_and_expression AND_OP inclusive_or_expression
	;

logical_or_expression
	: logical_and_expression
	| logical_or_expression OR_OP logical_and_expression
	;

assignment_expression
	: logical_or_expression
	| unary_expression assignment_operator assignment_expression
	;

assignment_operator
	: '='
	| MUL_ASSIGN
	| DIV_ASSIGN
	| MOD_ASSIGN
	| ADD_ASSIGN
	| SUB_ASSIGN
	| LEFT_ASSIGN
	| RIGHT_ASSIGN
	| AND_ASSIGN
	| XOR_ASSIGN
	| OR_ASSIGN
	;

expression
	: assignment_expression
	| expression ',' assignment_expression
	;

constant_expression
	: logical_or_expression
	;
