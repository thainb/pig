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

package org.apache.pig.parser;

import java.io.IOException;

import junit.framework.Assert;

import org.antlr.runtime.CharStream;
import org.antlr.runtime.CommonTokenStream;
import org.antlr.runtime.RecognitionException;
import org.antlr.runtime.tree.CommonTree;
import org.antlr.runtime.tree.Tree;
import org.junit.Test;

public class TestQueryParser {

    @Test
    public void test() throws IOException, RecognitionException  {
        CharStream input = new QueryParserFileStream( "test/org/apache/pig/parser/TestParser.pig" );
        QueryLexer lexer = new QueryLexer(input);
        CommonTokenStream tokens = new  CommonTokenStream(lexer);

        QueryParser parser = new QueryParser(tokens);
        QueryParser.query_return result = parser.query();

        Tree ast = (Tree)result.getTree();

        System.out.println( ast.toStringTree() );
        TreePrinter.printTree( (CommonTree)ast, 0 );
        Assert.assertEquals( 0, lexer.getNumberOfSyntaxErrors() );
        Assert.assertEquals( 0, parser.getNumberOfSyntaxErrors() );
    }

    @Test
    public void testNegative1() throws IOException, RecognitionException {
        shouldFail("A = load 'x'; B=A;");
    }
    
    @Test
    public void testNegative2() throws IOException, RecognitionException {
        shouldFail("A = load 'x'; B=(A);");
    }

    @Test
    public void testNegative3() throws IOException, RecognitionException {
        shouldFail("A = load 'x';B = (A) as (a:int, b:long);");
    }

    @Test
    public void testNegative4() throws IOException, RecognitionException {
        shouldFail("A = load 'x'; B = ( filter A by $0 == 0 ) as (a:bytearray, b:long);");
    }
    
    @Test
    public void testNegative5() throws IOException, RecognitionException {
        shouldFail("A = load 'x'; D = group A by $0:long;");
    }
    
    @Test
    public void testNegative6() throws IOException, RecognitionException {
        shouldFail("A = load '/Users/gates/test/data/studenttab10'; B = foreach A generate $0, 3.0e10.1;");
    }
    
    @Test
    public void test2() throws IOException, RecognitionException {
        shouldPass("A = load '/Users/gates/test/data/studenttab10'; B = foreach A generate ( $0 == 0 ? 1 : 0 );");
    }

    @Test
    public void test3() throws IOException, RecognitionException {
        shouldPass("a = load '1.txt' as (a0); b = foreach a generate flatten((bag{T:tuple(m:map[])})a0) as b0:map[];c = foreach b generate (long)b0#'key1';");
    }

    @Test
    public void testBagType() throws IOException, RecognitionException {
        String query = "a = load '1.txt' as ( u : bag{}, v : bag{tuple(x, y)} );" +
            "b = load '2.x' as ( t : {}, u : {(r,s)}, v : bag{ T : tuple( x, y ) }, w : bag{(z1, z2)} );" +
            "c = load '3.x' as p : int;";
        int errorCount = parse( query );
        Assert.assertTrue( errorCount == 0 );
    }

    @Test
    public void testFlatten() throws IOException, RecognitionException {
        String query = "a = load '1.txt' as ( u, v, w : int );" +
            "b = foreach a generate * as ( x, y, z ), flatten( u ) as ( r, s ), flatten( v ) as d, w + 5 as e:int;";
        int errorCount = parse( query );
        Assert.assertTrue( errorCount == 0 );
    }

    @Test
    public void testAST() throws IOException, RecognitionException  {
        CharStream input = new QueryParserFileStream( "test/org/apache/pig/parser/TestAST.pig" );
        QueryLexer lexer = new QueryLexer(input);
        CommonTokenStream tokens = new  CommonTokenStream(lexer);

        QueryParser parser = new QueryParser(tokens);
        QueryParser.query_return result = parser.query();

        Tree ast = (Tree)result.getTree();

        System.out.println( ast.toStringTree() );
        TreePrinter.printTree( (CommonTree)ast, 0 );
        Assert.assertEquals( 0, lexer.getNumberOfSyntaxErrors() );
        Assert.assertEquals( 0, parser.getNumberOfSyntaxErrors() );
   
        Assert.assertEquals( "QUERY", ast.getText() );
        Assert.assertEquals( 5, ast.getChildCount() );
        
        for( int i = 0; i < ast.getChildCount(); i++ ) {
            Tree c = ast.getChild( i );
            Assert.assertEquals( "STATEMENT", c.getText() );
        }
        
        Tree stmt = ast.getChild( 0 );
        Assert.assertEquals( "A", stmt.getChild( 0 ).getText() ); // alias
        Assert.assertTrue( "LOAD".equalsIgnoreCase( stmt.getChild( 1 ).getText() ) );
        
        stmt = ast.getChild( 1 );
        Assert.assertEquals( "B", stmt.getChild( 0 ).getText() ); // alias
        Assert.assertTrue( "FOREACH".equalsIgnoreCase( stmt.getChild( 1 ).getText() ) );
        
        stmt = ast.getChild( 2 );
        Assert.assertEquals( "C", stmt.getChild( 0 ).getText() ); // alias
        Assert.assertTrue( "FILTER".equalsIgnoreCase( stmt.getChild( 1 ).getText() ) );

        stmt = ast.getChild( 3 );
        Assert.assertEquals( "D", stmt.getChild( 0 ).getText() ); // alias
        Assert.assertTrue( "LIMIT".equalsIgnoreCase( stmt.getChild( 1 ).getText() ) );

        stmt = ast.getChild( 4 );
        Assert.assertTrue( "STORE".equalsIgnoreCase( stmt.getChild( 0 ).getText() ) );
    }

    @Test
    public void testMultilineFunctionArguments() throws RecognitionException, IOException {
        final String pre = "STORE data INTO 'testOut' \n" +
                           "USING PigStorage (\n";

        String lotsOfNewLines = "'{\"debug\": 5,\n" +
                                "  \"data\": \"/user/lguo/testOut/ComponentActTracking4/part-m-00000.avro\",\n" +
                                "  \"field0\": \"int\",\n" +
                                "  \"field1\": \"def:browser_id\",\n" +
                                "  \"field3\": \"def:act_content\" }\n '\n";

        String [] queries = { lotsOfNewLines,
                            "'notsplitatall'",
                            "'see you\nnext line'",
                            "'surrounded \n by spaces'",
                            "'\nleading newline'",
                            "'trailing newline\n'",
                            "'\n'",
                            "'repeated\n\n\n\n\n\n\n\n\nnewlines'",
                            "'also\ris\rsupported\r'"};

        final String post = ");";

        for(String q : queries) {
            shouldPass(pre + q + post);
        }
    }

    private void shouldPass(String query) throws RecognitionException, IOException {
        System.out.println("Testing: " + query);
        Assert.assertEquals(query + " should have passed", 0, parse(query));
    }

    private void shouldFail(String query) throws RecognitionException, IOException {
        System.out.println("Testing: " + query);
        Assert.assertFalse(query + " should have failed", 0 == parse(query));
    }
    
    private int parse(String query) throws IOException, RecognitionException  {
        CharStream input = new QueryParserStringStream( query );
        QueryLexer lexer = new QueryLexer(input);
        CommonTokenStream tokens = new  CommonTokenStream(lexer);

        QueryParser parser = new QueryParser(tokens);
        QueryParser.query_return result = parser.query();

        Tree ast = (Tree)result.getTree();

        System.out.println( ast.toStringTree() );
        TreePrinter.printTree((CommonTree) ast, 0);
        Assert.assertEquals(0, lexer.getNumberOfSyntaxErrors());
        return parser.getNumberOfSyntaxErrors();
    }

}
