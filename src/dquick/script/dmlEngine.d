module dquick.script.dml_engine;

import derelict.lua.lua;

import dquick.item.declarative_item;
import dquick.item.graphic_item;
import dquick.item.image_item;

import dquick.system.window;

import dquick.script.property_binding;
import dquick.script.utils;

import std.conv;
import std.file, std.stdio;
import std.string;
import core.memory;
import std.algorithm;
import std.traits;
import std.typetuple;
import std.c.string;


/*template	CreateWrapper(T)
{
	mixin("
		  class Toto
		  {
		  }
		  ");
}*/

version(unittest)
{
	/*interface TestBase(T) 
	{
	}

	template TestBaseTypeTuple2(A...)
	{
		static if (A.length == 0)
			alias A	TestBaseTypeTuple2;
		else
			alias TypeTuple!(TestBase!(A[0]), TestBaseTypeTuple2!(A[1 .. $])) TestBaseTypeTuple2;
	}

	template TestBaseTypeTuple(A)
	{
		alias TestBaseTypeTuple2!(BaseTypeTuple!(A))	TestBaseTypeTuple;
	}

	class Test(T) : TestBaseTypeTuple!(T)
	{
		this()
		{
			writeln(typeid(T), " base ", typeid(BaseTypeTuple!(typeof(this))));
		}
	}*/

	/*string	generateTest1(T)()
	{
		string	result;

		alias BaseTypeTuple!T	bases;
		string	basesString;
		foreach (base, bases)
			basesString ~= format("%s, ", fullyQualifiedName(base));
		basesString = chomp(basesString, ", ");

		format("class	Test1(%s) : %s {}", fullyQualifiedName(T), basesString);
	}

	mixin("class	Test1(T1) : Test1!(DeclarativeItem)
	{
	}");*/


	interface Interface
	{
		int		nativeProperty();
	}
	class SubItem : DeclarativeItem
	{
		void	nativeProperty(int value)
		{
			if (mNativeProperty != value)
			{
				mNativeProperty = value;
				onNativePropertyChanged.emit(value);
			}
		}
		int		nativeProperty()
		{
			return mNativeProperty;
		}
		mixin Signal!(int) onNativePropertyChanged;
		int		mNativeProperty;
	}
	class Item : DeclarativeItem, Interface
	{
		this()
		{
		}

		void	nativeProperty(int value)
		{
			if (mNativeProperty != value)
			{
				mNativeProperty = value;
				onNativePropertyChanged.emit(value);
			}
		}
		int		nativeProperty()
		{
			return mNativeProperty;
		}
		mixin Signal!(int) onNativePropertyChanged;
		int		mNativeProperty;

		void	nativeTotalProperty(int value)
		{
			if (mNativeTotalProperty != value)
			{
				mNativeTotalProperty = value;
				onNativeTotalPropertyChanged.emit(value);
			}
		}
		int		nativeTotalProperty()
		{
			return mNativeTotalProperty;
		}
		mixin Signal!(int) onNativeTotalPropertyChanged;
		int		mNativeTotalProperty;

		enum Enum
		{
			enumVal1,
			enumVal2,
		}
		void	nativeEnumProperty(Enum value)
		{
			if (mNativeEnumProperty != value)
			{
				mNativeEnumProperty = value;
				onNativeEnumPropertyChanged.emit(value);
			}
		}
		Enum		nativeEnumProperty()
		{
			return mNativeEnumProperty;
		}
		mixin Signal!(Enum) onNativeEnumPropertyChanged;
		Enum		mNativeEnumProperty;

		int	testNormalMethod(int a, int b)
		{
			return a + b + nativeProperty;
		}
		int	testNormalMethod2(Item a, Interface b)
		{
			return a.nativeProperty + b.nativeProperty + nativeProperty;
		}

		void	nativeSubItem(SubItem value)
		{
			if (mNativeSubItem != value)
			{
				mNativeSubItem = value;
				onNativeSubItemChanged.emit(value);
			}
		}
		SubItem		nativeSubItem()
		{
			return mNativeSubItem;
		}
		mixin Signal!(SubItem) onNativeSubItemChanged;
		SubItem		mNativeSubItem;
	}

	int	testSumFunctionBinding(int a, int b)
	{
		return a + b;
	}

	int	testSumFunctionBinding2(Item a, Interface b)
	{
		writefln("testSumFunctionBinding2 = %d %d", a.nativeProperty, b.nativeProperty);
		return a.nativeProperty + b.nativeProperty;
	}
}

unittest
{
	try {
	/*import std.typecons;

	interface A { int run(); }
	interface B { int stop(); @property int status(); }
	class X
	{
		int run() { return 1; }
		int stop() { return 2; }
		@property int status() { return 3; }
	}

	auto x = new X();
	auto ab = x.wrap!(A, B);
	pragma(msg, typeid(typeof(ab)));*/


	//auto test = new Test!Item;

	/*class	TestVoid {
		int i;
	}
	TestVoid	testVoid1 = new TestVoid;
	writefln("%x", cast(TestVoid*)testVoid1);
	testVoid1.i = 10;
	void*	testVoid2 = cast(void*)testVoid1;
	TestVoid	testVoid3 = cast(TestVoid)testVoid2;
	writefln("%x", cast(TestVoid*)testVoid3);*/



	DMLEngine	dmlEngine = new DMLEngine;
	dmlEngine.create();
	dmlEngine.addItemType!(Item, "Item");

	/*string lua8 = q"(
		Item {
			id = "item666",

			Item {
				id = "item667",
			}
		}
	)";
	dmlEngine.execute(lua8, "");*/

	// Test basic item
	string lua1 = q"(
		Item {
			id = "item1"
		}
	)";
	dmlEngine.execute(lua1, "");
	assert(dmlEngine.item!Item("item1") !is null);
	assert(dmlEngine.rootItem() !is null);
	assert(dmlEngine.rootItem().id == "item1");

	// Test native property
	string lua2 = q"(
		Item {
			id = "item2",
			nativeProperty = 100
		}
	)";
	dmlEngine.execute(lua2, "");
	assert(dmlEngine.item!Item("item2") !is null);
	assert(dmlEngine.item!Item("item2").nativeProperty == 100);
	dmlEngine.execute("item2.nativeProperty = item2.nativeProperty * 2", "");
	assert(dmlEngine.item!Item("item2").nativeProperty == 200);

	// Test virtual property
	string lua3 = q"(
		Item {
			id = "item3",
			virtualProperty = 1000,
			nativeProperty = 100
		}
		item3.nativeProperty = item3.virtualProperty + item3.nativeProperty
	)";
	dmlEngine.execute(lua3, "");
	assert(dmlEngine.item!Item("item3").nativeProperty == 1100);

	// Test signals
	string lua4 = q"(
		Item {
			id = "item4",
			nativeTotalProperty = 0,
			virtualProperty = 1000,
			onVirtualPropertyChanged = function()
				item4.nativeTotalProperty = item4.nativeTotalProperty + item4.virtualProperty
			end,
			nativeProperty = 100,
			onNativePropertyChanged = function()
				item4.nativeTotalProperty = item4.nativeTotalProperty + item4.nativeProperty
			end,
		}
		item4.virtualProperty = 10000
		item4.nativeProperty = 500
	)";
	dmlEngine.execute(lua4, "");
	assert(dmlEngine.item!Item("item4").nativeTotalProperty == 10500);

	// Test property binding
	string lua5 = q"(
		Item {
			id = "item5",
			nativeProperty = 100
		}
		Item {
			id = "item6",
			virtualProperty = function()
				return item5.nativeProperty + 50
			end
		}
		Item {
			id = "item7",
			nativeTotalProperty = function()
				return item6.virtualProperty + 25
			end
		}
	)";
	dmlEngine.execute(lua5, "");
	assert(dmlEngine.item!Item("item7").nativeTotalProperty == 175);

	// Test property binding loop detection
	/*string lua6 = q"(
		Item {
			id = "item8",
			nativeProperty = function()
				return item10.nativeTotalProperty + 100
			end
		}
		Item {
			id = "item9",
			virtualProperty = function()
				return item8.nativeProperty + 50
			end
		}
		Item {
			id = "item10",
			nativeTotalProperty = function()
				return item9.virtualProperty + 25
			end
		}
	)";
	dmlEngine.execute(lua6, "");*/

	// Test enums
	string lua7 = q"(
		Item {
			id = "item11",
			nativeEnumProperty = Item.Enum.enumVal2
		}
	)";
	dmlEngine.execute(lua7, "");
	assert(dmlEngine.item!Item("item11").nativeEnumProperty == Item.Enum.enumVal2);

	// Test simple property alias (parent to child)
	string lua8 = q"(
		Item {
			id = "item12",
			nativePropertyAlias = 100,

			Item {
				id = "item13",
				nativeProperty = function()
					return item12.nativePropertyAlias
				end
			}
		}
		item12.nativePropertyAlias = 200
	)";
	dmlEngine.execute(lua8, "");
	assert(dmlEngine.item!Item("item13").nativeProperty == 200);

	// Test 2 ways property alias (parent to child and parent to child, usefull for buttons that can be checked from qml or mouse input)
	string lua9 = q"(
		Item {
			id = "item14",

			Item {
				id = "item15",
				nativeProperty = 100,
				onNativePropertyChanged = function()
					item14.nativePropertyAlias = item15.nativeProperty
				end,
			},
			nativePropertyAlias = item15.nativeProperty,
			onNativePropertyAliasChanged = function()
				item15.nativeProperty = item14.nativePropertyAlias
			end,

			nativeTotalProperty = function() -- To test property nativeTotalProperty from D
				return item14.nativePropertyAlias
			end,
		}
	)";
	dmlEngine.execute(lua9, "");
	assert(dmlEngine.item!Item("item15").nativeProperty == 100); // Test init value propagation

	dmlEngine.execute("item14.nativePropertyAlias = 200", "");
	assert(dmlEngine.item!Item("item15").nativeProperty == 200); // Test propagation from parent to child

	dmlEngine.item!Item("item15").nativeProperty = 300;
	assert(dmlEngine.item!Item("item14").nativeTotalProperty == 300); // Test propagation from child to parent

	// Test function binding
	dmlEngine.addFunction!(testSumFunctionBinding, "testSumFunctionBinding")();
	string lua10 = q"(
		test = testSumFunctionBinding(100, 200)
	)";
	dmlEngine.execute(lua10, "");
	assert(dmlEngine.getLuaGlobal!int("test") == 300);

	// Test function binding with polymorphic object parameters
	dmlEngine.addFunction!(testSumFunctionBinding2, "testSumFunctionBinding2")();
	dmlEngine.execute("test2 = testSumFunctionBinding2(item2, item3)", "");
	int toto = 10;
	assert(dmlEngine.getLuaGlobal!int("test2") == 1300);

	// Test already existing class instance binding
	Item	testObject = new Item;
	dmlEngine.addObject(testObject, "testObject");
	testObject.nativeProperty = 1000;
	string lua11 = q"(
		testObject.nativeProperty = 2000;
	)";
	dmlEngine.execute(lua11, "");
	assert(testObject.nativeProperty == 2000);

	// Test normal method binding
	Item	testObject2 = new Item;
	dmlEngine.addObject(testObject2, "testObject2");
	testObject2.nativeProperty = 100;
	string lua12 = q"(
		total = testObject2.testNormalMethod(1, 10)
	)";
	dmlEngine.execute(lua12, "");
	assert(dmlEngine.getLuaGlobal!int("total") == 111);

	// Test normal method binding with polymorphic object parameters
	dmlEngine.execute("total2 = testObject2.testNormalMethod2(item2, item3)", "");
	assert(dmlEngine.getLuaGlobal!int("total2") == 1400);

	// Test subitem property binding
	{
		Item	testObject3 = new Item;
		dmlEngine.addObject(testObject3, "testObject3");

		dmlEngine.execute("subItemGlobal1 = testObject3.nativeSubItem", "");
		assert(dmlEngine.getLuaGlobal!SubItem("subItemGlobal1") is null);

		testObject3.nativeSubItem = new SubItem;
		dmlEngine.execute("subItemGlobal2 = testObject3.nativeSubItem", "");
		assert(dmlEngine.getLuaGlobal!SubItem("subItemGlobal2") !is null);

		testObject3.nativeSubItem.nativeProperty = 10;
		dmlEngine.execute("subItemGlobal3 = testObject3.nativeSubItem.nativeProperty", "");
		assert(dmlEngine.getLuaGlobal!int("subItemGlobal3") == 10);
		dmlEngine.execute("subItemGlobal4 = subItemGlobal2.nativeProperty", "");
		assert(dmlEngine.getLuaGlobal!int("subItemGlobal4") == 10);

		testObject3.nativeSubItem = new SubItem;
		testObject3.nativeSubItem.nativeProperty = 20;
		dmlEngine.execute("subItemGlobal5 = testObject3.nativeSubItem.nativeProperty", "");
		assert(dmlEngine.getLuaGlobal!int("subItemGlobal5") == 20);

		dmlEngine.addObject(testObject3, "testObject4");
		dmlEngine.execute("subItemGlobal6 = testObject3.nativeSubItem", "");
		dmlEngine.execute("subItemGlobal7 = testObject4.nativeSubItem", "");
		assert(dmlEngine.getLuaGlobal!SubItem("subItemGlobal6") is dmlEngine.getLuaGlobal!SubItem("subItemGlobal7"));

		dmlEngine.execute("testObject3.nativeSubItem.nativeProperty = 30", "");
		assert(testObject3.nativeSubItem.nativeProperty == 30);

		testObject3.nativeSubItem = new SubItem;
		dmlEngine.execute("testObject3.nativeSubItem = nil", "");
		assert(testObject3.nativeSubItem is null);
		testObject3.nativeSubItem = new SubItem;
		assert(testObject3.nativeSubItem !is null);
		testObject3.nativeSubItem = null;
		assert(testObject3.nativeSubItem is null);

		Item	testObject5 = new Item;
		dmlEngine.addObject(testObject5, "testObject5");
		dmlEngine.execute("testObject3.nativeSubItem = testObject5.nativeSubItem", "");
		assert(testObject3.nativeSubItem is null);
		testObject5.nativeSubItem = new SubItem;
		dmlEngine.execute("testObject3.nativeSubItem = testObject5.nativeSubItem", "");
		dmlEngine.execute("subItemGlobal8 = testObject3.nativeSubItem", "");
		assert(dmlEngine.getLuaGlobal!SubItem("subItemGlobal8") is testObject5.nativeSubItem);
	}
	}
	catch (Throwable e)
	{
		writeln(e.toString());
		int toto = 10;
	}
}

class DMLEngine : dquick.script.dml_engine_core.DMLEngineCore
{
public:
	static immutable bool showDebug = 0;

	void	toto()
	{
		/*class Toto666
		{
		}
		pragma(msg, typeid(Toto666));*/
	}
	void	addItemType(type, string luaName)()
	{
		/*alias CreateWrapper!(type)	BindingItemType;

		auto t = new BindingItemType.Toto;*/

		addObjectBindingType!(dquick.script.item_binding.ItemBinding!(type), luaName)();

	}

	void	addObject(T)(T object, string luaName)
	{
		addItemType!(T, "__dquick_reserved1");
		static if (is(T : DeclarativeItem))
			object.id = luaName;

		dquick.script.item_binding.ItemBinding!T	itemBinding = registerItem!T(object);
		setLuaGlobal(luaName, object);
	}

	DeclarativeItem	rootItem()
	{
		DeclarativeItem	result = rootItemBinding();
		if (result !is null)
			return result;
		foreach (key, binding; mItemsToItemBindings)
		{
			DeclarativeItem	declarativeItem = cast(DeclarativeItem)(key);
			if (declarativeItem && declarativeItem.parent() is null)
			{
				writeln("rootItem " ~ declarativeItem.id);
				return declarativeItem;
			}
		}
		return null;
	}

	T	item(T)(string id)
	{
		//auto toto = new dquick.script.dml_engine.DMLEngine.toto.Toto666;
		//pragma(msg, typeid(toto));

		auto itemBinding = itemBinding!(dquick.script.item_binding.ItemBinding!(T))(id);
		if (itemBinding !is null)
			return itemBinding.item;
		return null;
	}

	T	getLuaGlobal(T)(string name)
	{
		lua_getglobal(mLuaState, name.toStringz());
		if (lua_isnone(mLuaState, -1) || lua_isnil(mLuaState, -1))
			throw new Exception(format("global \"%s\" is nil\n", name));

		T	value;
		static if (is(T : dquick.item.declarative_item.DeclarativeItem))
		{
			auto itemBinding = dquick.script.utils.valueFromLua!(dquick.script.item_binding.ItemBinding!(T))(mLuaState, -1);
			if (itemBinding is null)
				return null;
			value = cast(T)(itemBinding.declarativeItem());
		}
		else
		{
			value = dquick.script.utils.valueFromLua!T(mLuaState, -1);
		}

		lua_pop(mLuaState, 1);
		return value;
	}

	void	setLuaGlobal(T)(string name, T value)
	{
		static if (is(T : dquick.item.declarative_item.DeclarativeItem))
		{
			dquick.script.item_binding.ItemBinding!T itemBinding = registerItem!(T)(value);
			dquick.script.utils.valueToLua!(dquick.script.item_binding.ItemBinding!T)(mLuaState, itemBinding);
		}
		else
		{
			dquick.script.utils.valueToLua!T(mLuaState, value);
		}

		lua_setglobal(mLuaState, name.toStringz());
	}

	void	addFunction(alias func, string luaName)()
	{
		string	functionMixin;
		static if (	isCallable!(func) &&
					isSomeFunction!(func) &&
				   __traits(isStaticFunction, func) &&
					   !isDelegate!(func))
		{
			static if (__traits(compiles, dquick.script.item_binding.generateFunctionOrMethodBinding!(func))) // Hack because of a bug in fullyQualifiedName
			{
				mixin("static " ~ dquick.script.item_binding.generateFunctionOrMethodBinding!(func));
				//pragma(msg, dquick.script.item_binding.generateFunctionOrMethodBinding!(func));

				/*static int	testSumFunctionBinding2(dquick.script.item_binding.ItemBindingBase!(dquick.script.dml_engine.Item) param0, dquick.script.item_binding.ItemBindingBase!(dquick.script.dml_engine.Item) param1)
				{
					writeln("wrapped function");
					dquick.script.dml_engine.Item	a = cast(dquick.script.dml_engine.Item)(param0.itemObject);
					return dquick.script.dml_engine.testSumFunctionBinding2(cast(dquick.script.dml_engine.Item)(param0.itemObject), cast(dquick.script.dml_engine.Item)(param1.itemObject));
				}*/

				mixin("alias " ~ __traits(identifier, func) ~ " wrappedFunc;");
				dquick.script.dml_engine_core.DMLEngineCore.addFunction!(wrappedFunc, luaName);
				//pragma(msg, dquick.script.item_binding.generateFunctionOrMethodBinding!(func));
			}
		}
	}
private:

	dquick.script.item_binding.ItemBinding!T	registerItem(T)(T item)
	{
		auto	refCountPtr = item in mItemsToItemBindings;
		if (refCountPtr !is null)
		{
			refCountPtr.count++;
			return cast(dquick.script.item_binding.ItemBinding!T)refCountPtr.iItemBinding;
		}

		dquick.script.item_binding.ItemBinding!T	itemBinding = new dquick.script.item_binding.ItemBinding!T(item);
		registerItem!T(item, itemBinding);
		addObjectBinding!(dquick.script.item_binding.ItemBinding!T)(itemBinding, "");
		return itemBinding;
	}
	dquick.script.item_binding.ItemBinding!T	registerItem(T)(T item, dquick.script.item_binding.ItemBinding!T itemBinding)
	{
		assert((item in mItemsToItemBindings) is null);
		itemBinding.dmlEngine = this;
		ItemRefCounting	newRefCount;
		newRefCount.count = 1;
		newRefCount.iItemBinding = itemBinding;
		mItemsToItemBindings[item] = newRefCount;
		return itemBinding;
	}

	void	unregisterItem(T)(T item)
	{
		auto	refCountPtr = item in mItemsToItemBindings;
		if (refCountPtr is null)
		{
			int toto = 10;
			writefln("");
		}
		assert(refCountPtr !is null);

		refCountPtr.count--;
		if (refCountPtr.count == 0)
			mItemsToItemBindings.remove(item);
	}

	struct ItemRefCounting
	{
		dquick.script.i_item_binding.IItemBinding	iItemBinding;
		uint										count;
	}
	ItemRefCounting[DeclarativeItem]	mItemsToItemBindings;
}
