%lex

%%
\s+         {/* skip whitespace */}
[0-9]+         {return 'NAT';}
"+"         {return '+';}

/lex

%%

E
    : E '+' T { console.log($0); }
    | T
    ;

T
    : NAT
    ;
