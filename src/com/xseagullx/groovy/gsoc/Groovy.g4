
grammar Groovy;

@lexer::members {
    enum Brace {
       ROUND,
       SQUARE,
       CURVE,
    };
    java.util.Deque<Brace> braceStack = new java.util.ArrayDeque<Brace>();
    Brace topBrace = null;
}

@parser::members {
    String currentClassName = null; // Used for correct constructor recognition.
}

// LEXER

LINE_COMMENT: '//' .*? '\n' -> type(NL) ;
BLOCK_COMMENT: '/*' .*? '*/' -> type(NL) ;

WS: [ \t]+ -> skip;

KW_CLASS: 'class' ;
KW_PACKAGE: 'package' ;
KW_IMPORT: 'import' ;
KW_EXTENDS: 'extends' ;
KW_IMPLEMENTS: 'implements' ;

KW_DEF: 'def' ;
KW_NULL: 'null' ;
KW_TRUE: 'true' ;
KW_FALSE: 'false' ;

KW_IN: 'in' ;
KW_FOR: 'for' ;
KW_IF: 'if' ;
KW_ELSE: 'else' ;
KW_WHILE: 'while' ;
KW_SWITCH: 'switch' ;
KW_CASE: 'case' ;
KW_DEFAULT: 'default' ;
KW_CONTINUE: 'continue' ;
KW_BREAK: 'break' ;
KW_RETURN: 'return' ;
KW_TRY: 'try' ;
KW_CATCH: 'catch' ;
KW_FINALLY: 'finally' ;
KW_THROW: 'throw' ;
KW_THROWS: 'throws' ;

STRING:
    '\'\'\'' STRING_ELEMENT*? '\'\'\''
    | '"""' STRING_ELEMENT*? '"""'
    | '\'' STRING_ELEMENT*? (NL | '\'')
    | '"' STRING_ELEMENT*? (NL | '"')
;

fragment STRING_ELEMENT: ESC_SEQUENCE | . ;
fragment ESC_SEQUENCE: '\\' [btnfr"'\\] | OCTAL_ESC_SEQ | UNICODE_ESC_SEQ ;
fragment OCTAL_ESC_SEQ: '\\' [0-3]? [0-7]? [0-7] ;
fragment UNICODE_ESC_SEQ: '\\u' [0-9abcdefABCDEF] [0-9abcdefABCDEF] [0-9abcdefABCDEF] [0-9abcdefABCDEF] ;

// Numbers
DECIMAL: SIGN? DIGITS ('.' DIGITS EXP_PART? | EXP_PART) DECIMAL_TYPE_MODIFIER? ;
INTEGER: SIGN? (('0x' | '0X') HEX_DIGITS | '0' OCT_DIGITS | DEC_DIGITS) INTEGER_TYPE_MODIFIER? ;

fragment DIGITS: [0-9] | [0-9][0-9_]*[0-9] ;
fragment DEC_DIGITS: [0-9] | [1-9][0-9_]*[0-9] ;
fragment OCT_DIGITS: [0-7] | [0-7][0-7_]*[0-7] ;
fragment HEX_DIGITS: [0-9abcdefABCDEF] | [0-9abcdefABCDEF][0-9abcdefABCDEF_]*[0-9abcdefABCDEF] ;  // Simplify by extracting one digit element?

fragment SIGN: ('-'|'+') ;
fragment EXP_PART: ([eE] SIGN? [0-9]+) ;

fragment INTEGER_TYPE_MODIFIER: ('G' | 'L' | 'I' | 'g' | 'l' | 'i') ;
fragment DECIMAL_TYPE_MODIFIER: ('G' | 'D' | 'F' | 'g' | 'd' | 'f') ;

// Modifiers
VISIBILITY_MODIFIER: (KW_PUBLIC | KW_PROTECTED | KW_PRIVATE) ;
fragment KW_PUBLIC: 'public' ;
fragment KW_PROTECTED: 'protected' ;
fragment KW_PRIVATE: 'private' ;

KW_ABSTRACT: 'abstract' ;
KW_STATIC: 'static' ;
KW_FINAL: 'final' ; // Class
KW_TRANSIENT: 'transient' ; // methods and fields
KW_NATIVE: 'native' ; // Methods and fields, as fields are accesors in Groovy.
KW_VOLATILE: 'volatile' ; // Fields only
KW_SYNCHRONIZED: 'synchronized' ; // Methods and fields.
KW_STRICTFP: 'strictfp';

LPAREN : '(' { braceStack.push(Brace.ROUND); topBrace = braceStack.peekFirst(); } ;
RPAREN : ')' { braceStack.pop(); topBrace = braceStack.peekFirst(); } ;
LBRACK : '[' { braceStack.push(Brace.SQUARE); topBrace = braceStack.peekFirst(); } ;
RBRACK : ']' { braceStack.pop(); topBrace = braceStack.peekFirst(); } ;
LCURVE : '{' { braceStack.push(Brace.CURVE); topBrace = braceStack.peekFirst(); } ;
RCURVE : '}' { braceStack.pop(); topBrace = braceStack.peekFirst(); } ;

/** Nested newline within a (..) or [..] are ignored. */
IGNORE_NEWLINE : '\r'? '\n' { topBrace == Brace.ROUND || topBrace == Brace.SQUARE }? -> skip ;

// Match both UNIX and Windows newlines
NL: '\r'? '\n';

IDENTIFIER: [A-Za-z][A-Za-z0-9_]*;

// PARSER

compilationUnit: (NL*) packageDefinition? (NL | ';')* (importStatement | NL)* (NL | ';')* (classDeclaration | NL)* EOF;

packageDefinition:
    (annotationClause (NL | annotationClause)*)? KW_PACKAGE (IDENTIFIER ('.' IDENTIFIER)*);
importStatement:
    (annotationClause (NL | annotationClause)*)? KW_IMPORT (IDENTIFIER ('.' IDENTIFIER)* ('.' '*')?);
classDeclaration:
    ((annotationClause | classModifier) (NL | annotationClause | classModifier)*)? KW_CLASS IDENTIFIER { currentClassName = $IDENTIFIER.text; } genericDeclarationList? (KW_EXTENDS genericClassNameExpression)? (KW_IMPLEMENTS genericClassNameExpression (',' genericClassNameExpression)*)? (NL)* '{' (classMember | NL | ';')* '}' ;
classMember:
    constructorDeclaration | methodDeclaration | fieldDeclaration | objectInitializer | classInitializer;

// Members // FIXME Make more strict check for def keyword. It can't repeat.
methodDeclaration:
    (
        (memberModifier | annotationClause | KW_DEF) (memberModifier | annotationClause | KW_DEF | NL)* (
            (genericDeclarationList genericClassNameExpression) | typeDeclaration
        )?
    |
        genericClassNameExpression
    )
    IDENTIFIER '(' argumentDeclarationList ')' throwsClause? '{' blockStatement? '}'
;

fieldDeclaration:
    (memberModifier | annotationClause | KW_DEF) (memberModifier | annotationClause | KW_DEF | NL)* genericClassNameExpression? IDENTIFIER
    | genericClassNameExpression IDENTIFIER
;
constructorDeclaration: { _input.LT(_input.LT(1).getType() == VISIBILITY_MODIFIER ? 2 : 1).getText().equals(currentClassName) }?
    VISIBILITY_MODIFIER? IDENTIFIER '(' argumentDeclarationList ')' throwsClause? '{' blockStatement? '}' ; // Inner NL 's handling.
objectInitializer: '{' blockStatement? '}' ;
classInitializer: KW_STATIC '{' blockStatement? '}' ;

typeDeclaration:
    (genericClassNameExpression | KW_DEF)
;

annotationClause: //FIXME handle assignment expression.
    '@' genericClassNameExpression ( '(' ((annotationElementPair (',' annotationElementPair)*) | annotationElement)? ')' )?
;
annotationElementPair: IDENTIFIER '=' annotationElement ;
annotationElement: expression | annotationClause ;

genericDeclarationList:
    '<' genericClassNameExpression (',' genericClassNameExpression)* '>'
;

throwsClause: KW_THROWS classNameExpression (',' classNameExpression)*;

argumentDeclarationList:
    argumentDeclaration (',' argumentDeclaration)* | /* EMPTY ARGUMENT LIST */ ;
argumentDeclaration:
    annotationClause* typeDeclaration? IDENTIFIER ;

blockStatement: (statement | NL)+ ;

statement:
    expression #expressionStatement
    | KW_FOR '(' (expression)? ';' expression? ';' expression? ')' '{' (statement | ';' | NL)* '}' #classicForStatement
    | KW_FOR '(' typeDeclaration? IDENTIFIER KW_IN expression')' '{' (statement | ';' | NL)* '}' #forInStatement
    | KW_IF '(' expression ')' '{' (statement | ';' | NL)*  '}' (KW_ELSE '{' (statement | ';' | NL)* '}')? #ifStatement
    | KW_WHILE '(' expression ')' '{' (statement | ';' | NL)*  '}'  #whileStatement
    | KW_SWITCH '(' expression ')' '{'
        (
          (caseStatement | NL)*
          (KW_DEFAULT ':' (statement | ';' | NL)*)?
        )
      '}' #switchStatement
    |  tryBlock ((catchBlock+ finallyBlock?) | finallyBlock) #tryCatchFinallyStatement
    | (KW_CONTINUE | KW_BREAK) #controlStatement
    | KW_RETURN expression? #returnStatement
    | KW_THROW expression #throwStatement
;

tryBlock: KW_TRY '{' blockStatement? '}' NL*;
catchBlock: KW_CATCH '(' ((classNameExpression ('|' classNameExpression)* IDENTIFIER) | IDENTIFIER) ')' '{' blockStatement? '}' NL*;
finallyBlock: KW_FINALLY '{' blockStatement? '}';

caseStatement: (KW_CASE expression ':' (statement | ';' | NL)* );

expression:
    '(' expression ')' #parenthesisExpression
    | '{' argumentDeclarationList '->' blockStatement? '}' #closureExpression
    | '[' (expression (',' expression)*)?']' #listConstructor
    | '[' (':' | (mapEntry (',' mapEntry)*) )']' #mapConstructor
    | expression ('.' | '?.' | '*.') IDENTIFIER '(' argumentList ')' #methodCallExpression
    | expression ('.' | '?.' | '*.' | '.@') IDENTIFIER #fieldAccessExpression
    | expression '(' argumentList? ')' #callExpression
    | expression ('--' | '++') #postfixExpression
    | ('!' | '~') expression #unaryExpression
    | ('+' | '-') expression #unaryExpression
    | ('--' | '++') expression #prefixExpression
    | expression ('**') expression #binaryExpression
    | expression ('*' | '/' | '%') expression #binaryExpression
    | expression ('+' | '-') expression #binaryExpression
    | expression ('<<' | '>>' | '>>>' | '..' | '..<') expression #binaryExpression
    | expression ((('<' | '<=' | '>' | '>=' | 'in') expression) | (('as' | 'instanceof') genericClassNameExpression)) #binaryExpression
    | expression ('==' | '!=' | '<=>') expression #binaryExpression
    | expression ('=~' | '==~') expression #binaryExpression
    | expression ('&') expression #binaryExpression
    | expression ('^') expression #binaryExpression
    | expression ('|') expression #binaryExpression
    | expression ('&&') expression #binaryExpression
    | expression ('||') expression #binaryExpression
    | expression ('=' | '+=' | '-=' | '*=' | '/=' | '%=' | '&=' | '^=' | '|=' | '<<=' | '>>=' | '>>>=') expression #assignmentExpression
    | annotationClause* typeDeclaration IDENTIFIER ('=' expression)? #declarationExpression
    | STRING #constantExpression
    | DECIMAL #constantDecimalExpression
    | INTEGER #constantIntegerExpression
    | KW_NULL #nullExpression
    | (KW_TRUE | KW_FALSE) #boolExpression
    | IDENTIFIER #variableExpression ;

classNameExpression: IDENTIFIER ('.' IDENTIFIER)* ;

genericClassNameExpression: classNameExpression genericDeclarationList? ;

mapEntry:
    STRING ':' expression
    | IDENTIFIER ':' expression
    | '(' expression ')' ':' expression
;

classModifier: //JSL7 8.1 FIXME Now gramar allows modifier duplication. It's possible to make it more strict listing all 24 permutations.
VISIBILITY_MODIFIER | KW_STATIC | (KW_ABSTRACT | KW_FINAL) | KW_STRICTFP ;

memberModifier:
    VISIBILITY_MODIFIER | KW_STATIC | (KW_ABSTRACT | KW_FINAL) | KW_NATIVE | KW_SYNCHRONIZED | KW_TRANSIENT | KW_VOLATILE ;

argumentList: expression (',' expression)* ;
