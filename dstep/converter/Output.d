/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.converter.Output;

static import std.array;

import mambo.core.string;

import clang.Cursor;
import dstep.converter.Type;

class Output
{
	String before;
	String after;
	String imports;
	String functions;
	String buffer;
	
	Class[] classes;
	Class[] interfaces;
	
	Class currentClass;
	Class currentInterface;
	
	this ()
	{
		before = new String;
		after = new String;
		imports = new String;
		functions = new String;
		buffer = new String;
		
		currentClass = new Class;
		currentInterface = new Class;
	}
	
	Output opOpAssign (string op, T) (T t) if (op == "~")
	{
		buffer ~= t;
		return this;
	}
	
	Output opOpAssign (string op) (NewLine) if (op == "~")
	{
		buffer ~= '\t';
		return this;
	}
	
	Output append (T) (T t)
	{
		buffer ~= t;
		return this;
	}
	
	Output append () (NewLine)
	{
		buffer ~= '\t';
		return this;
	}
	
	Output appendnl (T) (T t)
	{
		buffer ~= t;
		buffer ~= nl;
		return this;
	}
	
	@property string data ()
	{
		buffer ~= before.data;
		buffer ~= imports.data;
		buffer ~= nl;
		
		foreach (cls ; classes)
			buffer ~= cls.data;
		
		buffer ~= currentClass.data;
		
		foreach (e ; interfaces)
			buffer ~= e.data;
		
		buffer ~= currentInterface.data;
		buffer ~= functions.data;
		buffer ~= after.data;
		
		return buffer.data;
	}
	
	string toString ()
	{
		return data;
	}
}

class Class : String
{
	private bool[string] mangledMethods;
	
	string getMethodName (FunctionCursor func, string name = "")
	{
		auto mangledName = mangle(func, name);
		auto selector = func.spelling;
		
		if (!(mangledName in mangledMethods))
		{
			mangledMethods[mangledName] = true;
			name = name.isBlank ? selector : name;
			return convertSelector(name);
		}
		
		return convertSelector(name, true);
	}
	
	private string mangle (FunctionCursor func, string name)
	{
		auto selector = func.spelling;
		name = name.isBlank ? convertSelector(selector) : name;
		auto mangledName = name;
		
		foreach (param ; func.parameters)
			mangledName ~= "_" ~ convertType(param.type);
			
		return mangledName;
	}
}

class String
{
	private
	{
		std.array.Appender!(string) appender;
		ubyte indendationLevel;
		ubyte prevIndendationLevel;
		bool shouldIndent;
	}
	
	void opOpAssign (string op, T) (T t) if (op == "~" && !is(T == NewLine))
	{
		put(t);
	}
	
	void opOpAssign (string op) (NewLine) if (op == "~")
	{
		put(nl);
	}
	
	void put (T) (T t) if (!is(T == NewLine))
	{
		if (shouldIndent)
		{
			_indent();
			shouldIndent = false;
		}

		appender.put(t);
	}
	
	void put () (NewLine)
	{
		appender.put('\n');
		shouldIndent = indendationLevel > 0;
	}
	
	@property string data ()
	{
		return appender.data;
	}
	
	Indendation indent ()
	{
		return indent(1);
	}
	
	Indendation indent (ubyte indendationLevel)
	{
		prevIndendationLevel = this.indendationLevel;
		this.indendationLevel = indendationLevel;
		return Indendation(this);
	}
	
	static struct Indendation
	{
		private String str;
		
		void opIn (void delegate () dg)
		{
			str._indent;
			dg();
			str.indendationLevel = str.prevIndendationLevel;
		}
	}
	
private:
	
	void _indent ()
	{
		foreach (i ; 0 .. indendationLevel)
			appender.put('\t');
	}
}

struct NewLine {}
NewLine nl;