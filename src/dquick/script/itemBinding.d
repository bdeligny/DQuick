module dquick.script.item_binding;

import std.traits;
import std.typetuple;
import std.string;
import std.stdio;
import std.signals;

import dquick.item.declarative_item;
import dquick.script.native_property_binding;
import dquick.script.virtual_property_binding;
import dquick.script.utils;

static string	I_ITEM_BINDING()
{
	return ITEM_BINDING() ~ "
		override void	dmlEngine(dquick.script.dml_engine_core.DMLEngineCore dmlEngine) {mDMLEngine = dmlEngine;}
	";
}

static string	ITEM_BINDING()
{
	return "
		dquick.script.dml_engine_core.DMLEngineCore	mDMLEngine;
		override dquick.script.dml_engine_core.DMLEngineCore	dmlEngine() {return mDMLEngine;};

		bool	mCreating;
		bool	creating() {return mCreating;}
		void	creating(bool creating) {mCreating = creating;}

		dquick.script.virtual_property_binding.VirtualPropertyBinding[string]	virtualProperties;

		override void	executeBindings()
		{
			foreach (member; __traits(allMembers, typeof(this)))
			{
				static if (is(typeof(__traits(getMember, this, member)) : dquick.script.property_binding.PropertyBinding))
				{
					assert(__traits(getMember, this, member) !is null);
					__traits(getMember, this, member).executeBinding();
				}
			}
			foreach (member; virtualProperties)
				member.executeBinding();
		}

		static if (dquick.script.dml_engine.DMLEngine.showDebug)
		{
			override string	displayDependents()
			{
				string	result;
				foreach (member; __traits(allMembers, typeof(this)))
				{
					static if (is(typeof(__traits(getMember, this, member)) : dquick.script.property_binding.PropertyBinding))
					{
						assert(__traits(getMember, this, member) !is null);
						result ~= format(\"%s\n\", member);
						result ~= shiftRight(__traits(getMember, this, member).displayDependents(), \"\t\", 1);
					}
				}
				return result;
			}
		}
		";
}

static bool		isProperty(T, string member)()
{
	static if (__traits(compiles, __traits(getOverloads, T, member)))
	{
		foreach (overload; __traits(getOverloads, T, member)) 
		{
			static if (isCallable!(overload))
			{
				static if (!is(ReturnType!(overload) == void) && TypeTuple!(ParameterTypeTuple!overload).length == 0) // Has a getter
				{
					static if (__traits(hasMember, T, getSignalNameFromPropertyName(member))) // Has a signal
						return true;
				}
			}
		}
	}
	return false;
}

static string	genProperties(T, propertyTypes...)()
{
	string result = "";

	foreach (member; __traits(allMembers, T))
	{
		static if (isProperty!(T, member)) // Property
		{
			static if (__traits(compiles, __traits(getOverloads, T, member)))
			{
				foreach (overload; __traits(getOverloads, T, member)) 
				{
					static if (isCallable!(overload))
					{
						static if (!is(ReturnType!(overload) == void) && TypeTuple!(ParameterTypeTuple!overload).length == 0) // Has a getter
						{
							static if (__traits(hasMember, T, getSignalNameFromPropertyName(member))) // Has a signal
							{
								static if (is(ReturnType!(overload) : dquick.item.declarative_item.DeclarativeItem))
								{
									result ~= format("	void															__%s(%s value) {
															if (!(value is null && ____%sItemBinding is null) && !(____%sItemBinding && value is ____%sItemBinding.item))
															{
																if (____%sItemBinding)
																	dmlEngine2.unregisterItem!(%s)(____%sItemBinding.item);
																if (value)
																	____%sItemBinding = dmlEngine2.registerItem!(%s)(value);
																else
																	____%sItemBinding = null;
																__%s.emit(____%sItemBinding);
															}																
														}",
													 getSignalNameFromPropertyName(member), fullyQualifiedName2!(ReturnType!(overload)),
													 member, member, member,
													 member,
													 fullyQualifiedName2!(ReturnType!(overload)), member,
													 member, fullyQualifiedName2!(ReturnType!(overload)),
													 member,
													 getSignalNameFromPropertyName(member~"ItemBinding"), member);	// Item Signal

									result ~= format("	dquick.script.item_binding.ItemBinding!(%s)					____%sItemBinding;\n", fullyQualifiedName2!(ReturnType!(overload)), member); // ItemBinding
									result ~= format("	dquick.script.item_binding.ItemBinding!(%s)					__%sItemBinding() {
															return ____%sItemBinding;
														}",
													 fullyQualifiedName2!(ReturnType!(overload)), member,
													 member); // ItemBinding Getter
									result ~= format("	void															__%sItemBinding(dquick.script.item_binding.ItemBinding!(%s) value) {
															if (value != ____%sItemBinding)
															{
																if (____%sItemBinding !is null)
																	dmlEngine2.unregisterItem!(%s)(____%sItemBinding.item);
																 ____%sItemBinding = value;
																if (____%sItemBinding !is null)
																{
																	dmlEngine2.registerItem!(%s)(____%sItemBinding.item);
																	item.%s = value.item;
																}
																else
																{
																	item.%s = null;
																}
																__%s.emit(value);
															}
														}",
													 member, fullyQualifiedName2!(ReturnType!(overload)),
													 member,
													 member,
													 fullyQualifiedName2!(ReturnType!(overload)), member,
													 member,
													 member,
													 fullyQualifiedName2!(ReturnType!(overload)), member,
													 member,
													 member,
													 getSignalNameFromPropertyName(member~"ItemBinding"));	// ItemBinding Setter
									result ~= format("	mixin Signal!(dquick.script.item_binding.ItemBinding!(%s))	__%s;", fullyQualifiedName2!(ReturnType!(overload)), getSignalNameFromPropertyName(member~"ItemBinding"));

									result ~= format("	dquick.script.native_property_binding.NativePropertyBinding!(dquick.script.item_binding.ItemBinding!(%s), dquick.script.item_binding.ItemBinding!T, \"__%sItemBinding\")	%s;\n", fullyQualifiedName2!(ReturnType!(overload)), member, member~"Property");
								}
								else
									result ~= format("	dquick.script.native_property_binding.NativePropertyBinding!(%s, T, \"%s\")\t%s;\n", fullyQualifiedName2!(ReturnType!(overload)), member, member~"Property");
							}
						}
					}
				}
			}
		}
		static if (isProperty!(T, member) == false)
		{
			static if (__traits(compiles, generateMethodBinding!(T, member))) // Method
				result ~= generateMethodBinding!(T, member);
		}
		static if (__traits(compiles, EnumMembers!(__traits(getMember, T, member))) && is(OriginalType!(__traits(getMember, T, member)) == int)) // If its an int enum
		{
			result ~= format("alias %s	%s;", fullyQualifiedName2!(__traits(getMember, T, member)), member);
		}
	}

	return result;
}

string	generateFunctionOrMethodBinding(alias overload)()
{
	string result;

	// Collect all argument in a tuple
	string	parameters;
	alias ParameterTypeTuple!(overload) MyParameterTypeTuple;

	foreach (index, paramType; MyParameterTypeTuple)
	{
		static if (is(paramType == class) || is(paramType == interface))
			parameters ~= format("dquick.script.item_binding.ItemBindingBase!(%s) param%d, ", fullyQualifiedName2!(paramType), index);
		else
			parameters ~= format("%s param%d, ", fullyQualifiedName2!(paramType), index);
	}
	parameters = chomp(parameters, ", ");

	string	callParameters;
	foreach (index, paramType; MyParameterTypeTuple)
	{
		static if (is(paramType == class) || is(paramType == interface))
			callParameters ~= format("cast(%s)(param%d.itemObject), ", fullyQualifiedName2!(paramType), index);
		else
			callParameters ~= format("param%d, ", index);
	}
	callParameters = chomp(callParameters, ", ");

	result ~= format("%s	%s(%s)\n", fullyQualifiedName2!(ReturnType!(overload)), __traits(identifier, overload), parameters);
	result ~= format("{\n");
	static if (__traits(isStaticFunction, overload))
		result ~= format("	return %s(%s);\n", fullyQualifiedName2!(overload), callParameters);
	else
		result ~= format("	return item.%s(%s);\n", __traits(identifier, overload), callParameters);
	result ~= format("}\n");

	return result;
}

string	generateMethodBinding(T, string member)()
{
	string result;

	foreach (overload; __traits(getOverloads, T, member)) 
	{
		static if (	isCallable!(overload) &&
					isSomeFunction!(overload) &&
				   !__traits(isStaticFunction, overload) &&
					   !isDelegate!(overload) &&
					   member != "__ctor" && member != "__dtor" /*dont want constructor nor destructor*/ &&
					   !__traits(hasMember, object.Object, member) /*dont want objects base methods*/)
		{
			static if (__traits(compiles, fullyQualifiedName2!(ReturnType!(overload)))) // Hack because of a bug in fullyQualifiedName
			{
				result ~= generateFunctionOrMethodBinding!(overload);
			}
		}
	}

	return result;
}

template ItemBindingBaseTypeTuple2(A...) // Transform types in ItemBindingBases
{
	static if (A.length == 0)
		alias A	ItemBindingBaseTypeTuple2;
	else
		alias TypeTuple!(ItemBindingBase!(A[0]), ItemBindingBaseTypeTuple2!(A[1 .. $])) ItemBindingBaseTypeTuple2;
}

template ItemBindingBaseTypeTuple(A) // Return base types transformed in ItemBindingBases
{
	alias ItemBindingBaseTypeTuple2!(BaseTypeTuple!(A))	ItemBindingBaseTypeTuple;
}

interface ItemBindingBase(T) : dquick.script.i_item_binding.IItemBinding, ItemBindingBaseTypeTuple!(T) // Proxy the T inheritance hierarchy
{
	Object	itemObject();
}

class ItemBinding(T) : ItemBindingBase!(T) // Proxy that auto bind T
{
	this(T item)
	{
		this.item = item;

		foreach (member; __traits(allMembers, typeof(this)))
		{
			static if (is(typeof(__traits(getMember, this, member)) : dquick.script.property_binding.PropertyBinding)) // Instantiate property binding
			{
				static immutable string propertyName = getPropertyNameFromPropertyDeclaration(member);
				static if (__traits(hasMember, this, "____"~propertyName~"ItemBinding")) // Instanciate subitem binding
				{
					__traits(getMember, this, member) = new typeof(__traits(getMember, this, member))(this, this);  // Instantiate property binding linked to __propertyName inside this
					__traits(getMember, this, "__"~getSignalNameFromPropertyName(propertyName~"ItemBinding")).connect(&__traits(getMember, this, member).onChanged); // Signal

					__traits(getMember, this.item, getSignalNameFromPropertyName(propertyName)).connect(&__traits(getMember, this, "__"~getSignalNameFromPropertyName(propertyName))); // Signal
					__traits(getMember, this, "__"~getSignalNameFromPropertyName(propertyName))(__traits(getMember, item, propertyName)); // Set initial value
				}
				else // Simple type
				{
					__traits(getMember, this, member) = new typeof(__traits(getMember, this, member))(this, item);  // Instantiate property binding linked to member inside item
					__traits(getMember, this.item, getSignalNameFromPropertyName(propertyName)).connect(&__traits(getMember, this, member).onChanged); // Signal
				}

			}
		}
	}

	this()
	{
		T item = new T;
		this(item);
	}

	~this()
	{
		foreach (member; __traits(allMembers, typeof(this)))
		{
			static if (is(typeof(__traits(getMember, this, member)) : dquick.script.property_binding.PropertyBinding))
			{
				assert(__traits(getMember, this, member) !is null);
				.destroy(__traits(getMember, this, member));
			}
		}

		.destroy(item);
	}

	T	item;
	DeclarativeItem	declarativeItem() {return item;}

	dquick.script.dml_engine.DMLEngine	dmlEngine2()
	{
		return cast(dquick.script.dml_engine.DMLEngine)(mDMLEngine);
	}

	//dquick.script.dml_engine.DMLEngine	dmlEngine()
	//{
	//	return dmlEngine;
	//}

	Object	itemObject() { return item;}

	override void			dmlEngine(dquick.script.dml_engine_core.DMLEngineCore dmlEngine)
	{
		if (mDMLEngine != dmlEngine)
		{
			mDMLEngine = dmlEngine;
			dmlEngine2.registerItem!T(item, this);
		}
	}

	mixin(genProperties!(T, dquick.script.dml_engine.DMLEngine.propertyTypes));
	
	mixin(ITEM_BINDING());
}