/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
 
/**
 * Parser file for Pig Parser
 *
 * NOTE: THIS FILE IS THE BASE FOR A FEW TREE PARSER FILES, such as AstValidator.g, 
 *       SO IF YOU CHANGE THIS FILE, YOU WILL PROBABLY NEED TO MAKE CORRESPONDING CHANGES TO 
 *       THOSE FILES AS WELL.
 */

parser grammar QueryParser;

options {
    tokenVocab=QueryLexer;
    output=AST;
    backtrack=true;
}

tokens {
    QUERY;
    STATEMENT;
    FUNC;
    FUNC_REF;
    FUNC_EVAL;
    CAST_EXPR;
    BIN_EXPR;
    TUPLE_VAL;
    MAP_VAL;
    BAG_VAL;
    KEY_VAL_PAIR;
    FIELD_DEF;
    NESTED_CMD_ASSI;
    NESTED_CMD;
    NESTED_PROJ;
    SPLIT_BRANCH;
    FOREACH_PLAN;
    FOREACH_PLAN_SIMPLE;
    MAP_TYPE;
    TUPLE_TYPE;
    BAG_TYPE;
    NEG;
    EXPR_IN_PAREN;
    JOIN_ITEM;
}

@header {
package org.apache.pig.parser;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
}

@members {
private static Log log = LogFactory.getLog( QueryParser.class );

/*
@Override
protected Object recoverFromMismatchedToken(IntStream input, int ttype, BitSet follow) 
throws RecognitionException {
    throw new MismatchedTokenException( ttype, input );
}

@Override
public Object recoverFromMismatchedSet(IntStream input, RecognitionException e, BitSet follow)
throws RecognitionException {
    throw e;
}
*/

public String getErrorMessage(RecognitionException e, String[] tokenNames ) {
    List stack =  getRuleInvocationStack( e, this.getClass().getName() );
    String msg = null;
    if( e instanceof NoViableAltException ) {
        NoViableAltException nvae = (NoViableAltException)e;
        msg = " no viable alt; token = " + e.token + " (decision=" + nvae.decisionNumber + " state " + nvae.stateNumber + ")" +
            " decision=<<" + nvae.grammarDecisionDescription + ">>";
    } else {
        msg =  super.getErrorMessage( e, tokenNames );
    }
    return stack + " " + msg;
}

public String getTokenErrorDisplay(Token t) {
    return t.toString();
}

} // End of @members

/*
@rulecatch {
catch(RecognitionException e) {
    throw e;
}
}
*/

query : statement* 
     -> ^( QUERY statement* )
;

statement : general_statement
          | foreach_statement
          | split_statement          
;

split_statement : split_clause SEMI_COLON!
;

general_statement : ( alias EQUAL )? op_clause parallel_clause? SEMI_COLON 
                 -> ^( STATEMENT alias? op_clause parallel_clause? )
;

parallel_clause : PARALLEL^ INTEGER
;

// We need to handle foreach specifically because of the ending ';', which is not required 
// if there is a nested block. This is ugly, but it gets the job done.
foreach_statement : ( alias EQUAL )? foreach_clause
                 -> ^( STATEMENT alias? foreach_clause )
;

alias : IDENTIFIER
;

op_clause : define_clause 
          | load_clause
          | group_clause
          | store_clause
          | filter_clause
          | distinct_clause
          | limit_clause
          | sample_clause
          | order_clause
          | cross_clause
          | join_clause
          | union_clause
          | stream_clause
          | mr_clause
;

define_clause : DEFINE^ alias ( cmd | func_clause )
;

cmd : EXECCOMMAND^ ( ship_clause | cache_caluse | input_clause | output_clause | error_clause )*
;

ship_clause : SHIP^ LEFT_PAREN! path_list? RIGHT_PAREN!
;

path_list : QUOTEDSTRING ( COMMA QUOTEDSTRING )* 
         -> QUOTEDSTRING+
;

cache_caluse : CACHE^ LEFT_PAREN! path_list RIGHT_PAREN!
;

input_clause : INPUT^ LEFT_PAREN! stream_cmd_list RIGHT_PAREN!
;

stream_cmd_list : stream_cmd ( COMMA stream_cmd )*
               -> stream_cmd+
;

stream_cmd : ( STDIN | STDOUT | QUOTEDSTRING )^ ( USING! ( func_clause ) )?
;

output_clause : OUTPUT^ LEFT_PAREN! stream_cmd_list RIGHT_PAREN!
;

error_clause : STDERROR^ LEFT_PAREN! QUOTEDSTRING ( LIMIT! INTEGER )? RIGHT_PAREN!
;

load_clause : LOAD^ filename ( USING! func_clause )? as_clause?
;

filename : QUOTEDSTRING
;

as_clause: AS^ ( field_def | field_def_list )
;

field_def : IDENTIFIER ( COLON type )?
     -> ^( FIELD_DEF IDENTIFIER type? )
;

field_def_list : LEFT_PAREN field_def ( COMMA field_def )* RIGHT_PAREN
     -> field_def+
;

type : simple_type | tuple_type | bag_type | map_type
;

simple_type : INT | LONG | FLOAT | DOUBLE | CHARARRAY | BYTEARRAY
;

tuple_type : TUPLE? field_def_list
          -> ^( TUPLE_TYPE field_def_list )
;

bag_type : BAG? LEFT_CURLY ( ( IDENTIFIER COLON )? tuple_type )? RIGHT_CURLY
        -> ^( BAG_TYPE tuple_type? )
;

map_type : MAP LEFT_BRACKET RIGHT_BRACKET
        -> MAP_TYPE
;

func_clause : func_name LEFT_PAREN func_args? RIGHT_PAREN
           -> ^( FUNC func_name func_args? )
            | func_alias
           -> ^( FUNC_REF func_alias )
;

func_name : eid ( ( PERIOD | DOLLAR ) eid )*
;

func_alias : IDENTIFIER
;

func_args_string : QUOTEDSTRING | MULTILINE_QUOTEDSTRING
;

func_args : func_args_string ( COMMA func_args_string )*
         -> func_args_string+
;

group_clause : ( GROUP | COGROUP )^ group_item_list ( USING! group_type )?
;

group_type : HINT_COLLECTED | HINT_MERGE | HINT_REGULAR
;

group_item_list : group_item ( COMMA group_item )*
               -> group_item+
;

group_item : rel ( join_group_by_clause | ALL | ANY ) ( INNER | OUTER )?
;

rel : alias | LEFT_PAREN! op_clause RIGHT_PAREN!
;

flatten_generated_item : flatten_clause ( AS! ( field_def | field_def_list ) )?
                       | expr ( AS! field_def )?
                       | STAR ( AS! ( field_def | field_def_list ) )?
;

flatten_clause : FLATTEN^ LEFT_PAREN! expr RIGHT_PAREN!
;

store_clause : STORE^ alias INTO! filename ( USING! func_clause )?
;

filter_clause : FILTER^ rel BY! cond
;

cond : or_cond
;

or_cond : and_cond  ( OR^ and_cond )*
;

and_cond : unary_cond ( AND^ unary_cond )*
;

unary_cond : LEFT_PAREN! cond RIGHT_PAREN!
           | expr rel_op^ expr
           | func_eval
           | null_check_cond
           | not_cond
;

not_cond : NOT^ unary_cond
;

func_eval : func_name LEFT_PAREN real_arg_list? RIGHT_PAREN
          -> ^( FUNC_EVAL func_name real_arg_list? )
;

real_arg_list : real_arg ( COMMA real_arg )*
             -> real_arg+
;

real_arg : expr | STAR
;

null_check_cond : expr IS! NOT? NULL^
;

expr : add_expr
;

add_expr : multi_expr ( ( PLUS | MINUS )^ multi_expr )*
;

multi_expr : cast_expr ( ( STAR | DIV | PERCENT )^ cast_expr )*
;

cast_expr : ( LEFT_PAREN type RIGHT_PAREN ) unary_expr
         -> ^( CAST_EXPR type unary_expr )
          | unary_expr
;

unary_expr : expr_eval 
           | LEFT_PAREN expr RIGHT_PAREN
          -> ^( EXPR_IN_PAREN expr )
           | neg_expr
;

expr_eval : const_expr | var_expr
;

var_expr : projectable_expr ( dot_proj | pound_proj )*
;

projectable_expr: func_eval | col_ref | bin_expr
;

dot_proj : PERIOD ( col_alias_or_index 
                  | ( LEFT_PAREN col_alias_or_index ( COMMA col_alias_or_index )* RIGHT_PAREN ) )
        -> ^( PERIOD col_alias_or_index+ )
;

col_alias_or_index : col_alias | col_index
;

col_alias : GROUP | IDENTIFIER
;

col_index : DOLLAR^ INTEGER
;

pound_proj : POUND^ ( QUOTEDSTRING | NULL )
;

bin_expr : LEFT_PAREN cond QMARK exp1 = expr COLON exp2 = expr RIGHT_PAREN
        -> ^( BIN_EXPR cond $exp1 $exp2 )
;

neg_expr : MINUS cast_expr
        -> ^( NEG cast_expr )
;

limit_clause : LIMIT^ rel ( INTEGER | LONGINTEGER )
;

sample_clause : SAMPLE^ rel DOUBLENUMBER
;

order_clause : ORDER^ rel BY! order_by_clause ( USING! func_clause )?
;

order_by_clause : STAR ( ASC | DESC )?
                | order_col_list
;

order_col_list : order_col ( COMMA order_col )*
              -> order_col+
;

order_col : col_ref ( ASC | DESC )?
          | LEFT_PAREN! col_ref ( ASC | DESC )? RIGHT_PAREN!
;

distinct_clause : DISTINCT^ rel partition_clause?
;

partition_clause : PARTITION^ BY! func_name
;

cross_clause : CROSS^ rel_list partition_clause?
;

rel_list : rel ( COMMA rel )*
        -> rel+
;

join_clause : JOIN^ join_sub_clause ( USING! join_type )? partition_clause?
;

join_type : HINT_REPL | HINT_MERGE | HINT_SKEWED | HINT_DEFAULT
;

join_sub_clause : join_item ( LEFT | RIGHT | FULL ) OUTER? COMMA! join_item
                | join_item_list
;

join_item_list : join_item ( COMMA! join_item )+
;

join_item : rel join_group_by_clause
         -> ^( JOIN_ITEM  rel join_group_by_clause )
;

join_group_by_clause : BY^ join_group_by_expr_list
;

join_group_by_expr_list : LEFT_PAREN join_group_by_expr ( COMMA join_group_by_expr )* RIGHT_PAREN
                       -> join_group_by_expr+
                        | join_group_by_expr
;

join_group_by_expr : expr | STAR
;

union_clause : UNION^ ONSCHEMA? rel_list
;

foreach_clause : FOREACH^ rel foreach_plan
;

foreach_plan : nested_blk SEMI_COLON?
           -> ^( FOREACH_PLAN nested_blk )
            | ( generate_clause parallel_clause? SEMI_COLON )
           -> ^( FOREACH_PLAN_SIMPLE generate_clause parallel_clause? )
;

nested_blk : LEFT_CURLY! nested_command_list ( generate_clause SEMI_COLON! ) RIGHT_CURLY!
;

generate_clause : GENERATE flatten_generated_item ( COMMA flatten_generated_item )*
                  -> ^( GENERATE flatten_generated_item+ )
;

nested_command_list : ( nested_command SEMI_COLON )*
                   -> nested_command*
                    |
;

nested_command : IDENTIFIER EQUAL nested_op
              -> ^( NESTED_CMD IDENTIFIER nested_op )
               | IDENTIFIER EQUAL expr
              -> ^( NESTED_CMD_ASSI IDENTIFIER expr )
;

nested_op : nested_proj
          | nested_filter
          | nested_sort
          | nested_distinct
          | nested_limit
;

nested_proj : col_ref PERIOD col_ref_list
           -> ^( NESTED_PROJ col_ref col_ref_list )
;

col_ref_list : ( col_ref | ( LEFT_PAREN col_ref ( COMMA col_ref )* RIGHT_PAREN ) )
            -> col_ref+
;

nested_filter : FILTER^ nested_op_input BY! cond
;

nested_sort : ORDER^ nested_op_input BY!  order_by_clause ( USING! func_clause )?
;

nested_distinct : DISTINCT^ nested_op_input
;

nested_limit : LIMIT^ nested_op_input INTEGER
;

nested_op_input : col_ref | nested_proj
;

stream_clause : STREAM^ rel THROUGH! ( EXECCOMMAND | IDENTIFIER ) as_clause?
;

mr_clause : MAPREDUCE^ QUOTEDSTRING ( LEFT_PAREN! path_list RIGHT_PAREN! )? store_clause load_clause EXECCOMMAND?
;

split_clause : SPLIT rel INTO split_branch ( COMMA split_branch )+
            -> ^( SPLIT rel split_branch+ )
;

split_branch : IDENTIFIER IF cond
            -> ^( SPLIT_BRANCH IDENTIFIER cond )
;

col_ref : alias_col_ref | dollar_col_ref
;

alias_col_ref : GROUP | IDENTIFIER
;

dollar_col_ref : DOLLAR^ INTEGER
;

const_expr : literal
;

literal : scalar | map | bag | tuple
;


scalar : INTEGER | LONGINEGER | FLOATNUMBER | DOUBLENUMBER | QUOTEDSTRING | NULL
;

map : LEFT_BRACKET ( keyvalue ( COMMA keyvalue )* )? RIGHT_BRACKET
   -> ^( MAP_VAL keyvalue+ )
    | LEFT_BRACKET RIGHT_BRACKET
   -> ^( MAP_VAL )
;

keyvalue : map_key POUND const_expr
        -> ^( KEY_VAL_PAIR map_key const_expr )
;

map_key : QUOTEDSTRING | NULL
;

bag : LEFT_CURLY ( tuple ( COMMA tuple )* )? RIGHT_CURLY
   -> ^( BAG_VAL tuple+ )
    | LEFT_CURLY RIGHT_CURLY
   -> ^( BAG_VAL )
;

tuple : LEFT_PAREN ( literal ( COMMA const_expr )* )? RIGHT_PAREN
     -> ^( TUPLE_VAL literal+ )
      | LEFT_PAREN RIGHT_PAREN
     -> ^( TUPLE_VAL )
;

// extended identifier, handling the keyword and identifier conflicts. Ugly but there is no other choice.
eid : rel_str_op
    | DEFINE
    | LOAD
    | FILTER
    | FOREACH
    | MATCHES
    | ORDER
    | DISTINCT
    | COGROUP
    | JOIN
    | CROSS
    | UNION
    | SPLIT
    | INTO
    | IF
    | ALL
    | AS
    | BY
    | USING
    | INNER
    | OUTER
    | PARALLEL
    | PARTITION
    | GROUP
    | AND
    | OR
    | NOT
    | GENERATE
    | FLATTEN
    | EVAL
    | ASC
    | DESC
    | INT
    | LONG
    | FLOAT
    | DOUBLE
    | CHARARRAY
    | BYTEARRAY
    | BAG
    | TUPLE
    | MAP
    | IS
    | NULL
    | STREAM
    | THROUGH
    | STORE
    | MAPREDUCE
    | SHIP
    | CACHE
    | INPUT
    | OUTPUT
    | STDERROR
    | STDIN
    | STDOUT
    | LIMIT
    | SAMPLE
    | LEFT
    | RIGHT
    | FULL
    | IDENTIFIER
;

// relational operator
rel_op : rel_op_eq
       | rel_op_ne
       | rel_op_gt
       | rel_op_gte
       | rel_op_lt
       | rel_op_lte
       | STR_OP_MATCHES
;

rel_op_eq : STR_OP_EQ | NUM_OP_EQ
;

rel_op_ne : STR_OP_NE | NUM_OP_NE
;

rel_op_gt : STR_OP_GT | NUM_OP_GT
;

rel_op_gte : STR_OP_GTE | NUM_OP_GTE
;

rel_op_lt : STR_OP_LT | NUM_OP_LT
;

rel_op_lte : STR_OP_LTE | NUM_OP_LTE
;

rel_str_op : STR_OP_EQ
           | STR_OP_NE
           | STR_OP_GT
           | STR_OP_LT
           | STR_OP_GTE
           | STR_OP_LTE
           | STR_OP_MATCHES
;

