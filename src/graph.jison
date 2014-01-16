%{
Exp = require('../lib/exp');
Action = require('../lib/action');
State = require('../lib/state');
ParseHelpers = require('./parse_helpers');
%}

%lex

%%

\s+ {}
\"(\\.|[^"])*\" { return 'STRING_LITERAL'; }
\'(\\.|[^'])*\' { return 'STRING_LITERAL'; }
\#[^\n]*\n {}
'<<=' { return 'LEFT_ASSIGN'; }
'>>=' { return 'RIGHT_ASSIGN'; }
'->' { return 'TRIG_IN'; }
'<-' { return 'TRIG_OUT'; }
'<=' { return 'LE_OP'; }
'>=' { return 'GE_OP'; }
'===' { return 'EQQ_OP'; }
'==' { return 'EQ_OP'; }
'!==' { return 'NEE_OP'; }
'!=' { return 'NE_OP'; }
'&&' { return 'AND_OP'; }
'||' { return 'OR_OP'; }
'<<' { return 'LEFT_OP'; }
'>>' { return 'RIGHT_OP'; }
'*=' { return 'MUL_ASSIGN'; }
'/=' { return 'DIV_ASSIGN'; }
'%=' { return 'MOD_ASSIGN'; }
'+=' { return 'ADD_ASSIGN'; }
'-=' { return 'SUB_ASSIGN'; }
'&=' { return 'AND_ASSIGN'; }
'^=' { return 'XOR_ASSIGN'; }
'|=' { return 'OR_ASSIGN'; }
'@' { return 'TRIG_AT'; }
'[' { return '['; }
']' { return ']'; }
'(' { return '('; }
')' { return ')'; }
'{' { return '{'; }
'}' { return '}'; }
'<' { return '<'; }
'>' { return '>'; }
',' { return ','; }
';' { return ';'; }
'.' { return '.'; }
'=' { return '='; }
'&' { return '&'; }
'|' { return '|'; }
':' { return ':'; }
'^' { return '^'; }
'*' { return '*'; }
'/' { return '/'; }
'%' { return '%'; }
'+' { return '+'; }
'-' { return '-'; }
'~' { return '~'; }
'!' { return '!'; }
'?' { return '?'; }

'state' { return 'STATE'; }
[0-9]+ { return 'NUMBER'; }
\w+ { return 'WORD'; }

/lex

%start graph

%%

graph
	: states { return $1; };

states
	: state { $$ = [ $1 ]; }
	| states state { $$ = $1.concat( [ $2 ] ); };

state : STATE identifier state_flags '{' triggers '}' opt_semi { $$ = new State( $2, $5.enter, $5.leave, $5.at, $3 ); };

state_flags : { $$ = 0; } | '[' flags ']' { $$ = $2; };

flags : WORD { $$ = ParseHelpers.getFlag( $1 ); } | flags opt_comma WORD { $$ = $1 + ParseHelpers.getFlag( $3 ); };

triggers
	: { $$ = { enter: [], leave: [], at: [] }; }
	| triggers trigger opt_semi { $$ = ParseHelpers.joinTriggers( $1, $2 ); };

trigger
	: TRIG_IN '{' actions '}' { $$ = { enter: $3 }; }
	| TRIG_OUT '{' actions '}' { $$ = { leave: $3 }; }
	| TRIG_AT identifier '{' actions '}' { $$ = { at: { at: $2, exe: $4, to: undefined } }; }
	| TRIG_AT identifier TRIG_IN WORD '{' actions '}' { $$ = { at: { at: $2, exe: $6, to: $4 } }; }
	| TRIG_AT identifier TRIG_IN WORD { $$ = { at: { at: $2, exe: [], to: $4 } }; };

actions
	: { $$ = []; }
	| actions statement { $$ = $1.concat( [ $2 ] ); };

statement
	: conditional '{' actions '}' opt_semi { $$ = new Action.ConditionalAction( $1, $3 ); }
	| '=' assignment_expression ';' { $$ = new Action.ExpressionAction( $2 ); }
	| action ';' { $$ = $1; };

conditional
	: '?' expression { $$ = $2; };

action
	: async_specifier WORD { $$ = new Action.SimpleAction( $2, [], $1 ); }
	| async_specifier WORD argument_expression_list { $$ = new Action.SimpleAction( $2, $3, $1 ); };

async_specifier
	: { $$ = false; }
	| '!' { $$ = true; };

identifier
	: WORD { $$ = $1; }
	| NUMBER { $$ = $1; }
	| identifier '.' NUMBER { $$ = $1 + "." + $3; }
	| identifier '.' WORD { $$ = $1 + "." + $3; };

opt_semi : | ';';
opt_comma : | ',';

/* Expressions */

object_literal_property
	: WORD ':' expression { $$ = [ '"'+$1+'"', $3 ]; }
	| STRING_LITERAL ':' expression { $$ = [ $1, $3 ]; }
	;

object_literal_properties
	: object_literal_property { $$ = [ $1 ]; }
	| object_literal_properties ',' object_literal_property { $1.push( $3 ); $$ = $1; }
	;

object_literal
	: '{' '}' { $$ = $$ = new Exp.ObjectLiteralExp( [] ); }
	| '{' object_literal_properties '}' { $$ = new Exp.ObjectLiteralExp( $2 ); }
	;

primary_expression
	: WORD { $$ = new Exp.WordLiteralExp( $1 ); }
	| NUMBER { $$ = new Exp.NumberLiteralExp( $1 ); }
	| STRING_LITERAL { $$ = new Exp.StringLiteralExp( $1 ); }
	| object_literal { $$ = $1; }
	/* TODO: object literal */
	| '(' expression ')' { $$ = $2; }
	;

postfix_expression
	: primary_expression { $$ = $1; }
	| postfix_expression '[' expression ']' { $$ = new Exp.SubscriptExp( $1, $3 ); }
	| postfix_expression '(' ')' { $$ = new Exp.CallExp( $1, [] ); }
	| postfix_expression '(' argument_expression_list ')' { $$ = new Exp.CallExp( $1, $3 ); }
	| postfix_expression '.' WORD { $$ = new Exp.PropExp( $1, $3 ); }
	;

argument_expression_list
	: expression { $$ = [ $1 ]; }
	| argument_expression_list ',' expression { $$ = $1.concat( [ $3 ] ); }
	;

unary_expression
	: postfix_expression { $$ = $1; }
	| unary_operator unary_expression { $$ = new Exp.UnaryOpExp( $1, $2 ); }
	;

unary_operator
	: '+'
	| '-'
	| '~'
	| '!'
	;

multiplicative_expression
	: unary_expression { $$ = $1; }
	| multiplicative_expression '*' unary_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	| multiplicative_expression '/' unary_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	| multiplicative_expression '%' unary_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	;

additive_expression
	: multiplicative_expression { $$ = $1; }
	| additive_expression '+' multiplicative_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	| additive_expression '-' multiplicative_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	;

shift_expression
	: additive_expression { $$ = $1; }
	| shift_expression LEFT_OP additive_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	| shift_expression RIGHT_OP additive_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	;

relational_expression
	: shift_expression { $$ = $1; }
	| relational_expression '<' shift_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	| relational_expression '>' shift_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	| relational_expression LE_OP shift_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	| relational_expression GE_OP shift_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	;

equality_expression
	: relational_expression { $$ = $1; }
	| equality_expression EQ_OP relational_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	| equality_expression EQQ_OP relational_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	| equality_expression NE_OP relational_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	| equality_expression NEE_OP relational_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	;

and_expression
	: equality_expression { $$ = $1; }
	| and_expression '&' equality_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	;

exclusive_or_expression
	: and_expression { $$ = $1; }
	| exclusive_or_expression '^' and_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	;

inclusive_or_expression
	: exclusive_or_expression { $$ = $1; }
	| inclusive_or_expression '|' exclusive_or_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	;

logical_and_expression
	: inclusive_or_expression { $$ = $1; }
	| logical_and_expression AND_OP inclusive_or_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	;

logical_or_expression
	: logical_and_expression { $$ = $1; }
	| logical_or_expression OR_OP logical_and_expression { $$ = new Exp.OpExp( $1, $2, $3 ); }
	;

assignment_expression
	: expression { $$ = $1; }
	| unary_expression assignment_operator assignment_expression { $$ = new Exp.AssignmentExp( $1, $2, $3 ); }
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
	: logical_or_expression { $$ = $1; }
	;
