module dquick.script.dml_engine_core;

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

version(unittest)
{
	class Item : dquick.script.i_item_binding.IItemBinding
	{
		this()
		{
			nativePropertyProperty = new typeof(nativePropertyProperty)(this, this);
		}

		dquick.script.native_property_binding.NativePropertyBinding!(int, Item, "nativeProperty")	nativePropertyProperty;
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

		mixin(dquick.script.item_binding.ITEM_BINDING);
	}

	unittest
	{
		DMLEngineCore	dmlEngine = new DMLEngineCore;
		dmlEngine.create();
		dmlEngine.addObjectBindingType!(Item, "Item");

		// Test basic item
		string lua1 = q"(
			Item {
			id = "item1"
			}
			)";
		dmlEngine.execute(lua1, "");
	}

	class DMLEngineCore
	{
	public:
		this()
		{
		}

		~this()
		{
			destroy();
		}

		void	create()
		{
			destroy();

			mLuaState = luaL_newstate();
			luaL_openlibs(mLuaState);
			lua_atpanic(mLuaState, cast(lua_CFunction)&luaPanicFunction);
			initializationPhase = false;
			static if (showDebug)
				lvl = 0;
		}

		void	destroy()
		{
			if (mLuaState)
			{
				lua_close(mLuaState);
				mLuaState = null;
			}
		}

		void	addObjectBindingType(type, string luaName)()
		{
			// Create a lua table to host enums and factory
			lua_newtable(mLuaState);
			{
				// Add enums
				foreach (member; __traits(allMembers, type))
				{
					static if (__traits(compiles, EnumMembers!(__traits(getMember, type, member))) && is(OriginalType!(__traits(getMember, type, member)) == int)) // If its an int enum
					{
						// Create enum table
						lua_pushstring(mLuaState, member.toStringz());
						lua_newtable(mLuaState);
						{
							auto enumMembers = EnumMembers!(__traits(getMember, type, member));
							foreach (enumMember; enumMembers)
							{
								lua_pushstring(mLuaState, to!(string)(enumMember).toStringz());
								lua_pushinteger(mLuaState, cast(int)enumMember);

								lua_settable(mLuaState, -3);
							}
						}
						lua_settable(mLuaState, -3);
					}
				}

				// Create metatable
				lua_newtable(mLuaState);
				{
					// Call metamethod to instanciate type
					lua_pushstring(mLuaState, "__call");
					lua_pushcfunction(mLuaState, cast(lua_CFunction)&createLuaBind!(dquick.script.item_binding.ItemBinding!(type)));
					lua_settable(mLuaState, -3);
				}
				lua_setmetatable(mLuaState, -2);
			}
			// Add type to a global
			lua_setglobal(mLuaState, luaName.toStringz());
		}

		void	addFunction(alias func, string luaName)()
		{
			static assert(isSomeFunction!func, "func must be a function");

			lua_pushcfunction(mLuaState, cast(lua_CFunction)&functionLuaBind!func);
			lua_setglobal(mLuaState, luaName.toStringz());
		}

		void	addObjectBinding(T)(T object, string id = "")
		{
			static assert(is(T : dquick.script.i_item_binding.IItemBinding), "object must inherit from IItemBinding");

			addObjectBindingType!(T, "__dquick_reserved1");

			mVoidToDeclarativeItems[cast(void*)(itemBinding)] = itemBinding;
			if (id != "")
			{
				if (id in mIdToDeclarativeItems)
					throw new Exception(format("an object with id \"%s\" already exist\n", id));
				mIdToDeclarativeItems[id] = cast(dquick.script.i_item_binding.IItemBinding)itemBinding;
			}
			itemBinding.creating = false;

			setLuaGlobal(id, object);
		}

		bool	isCreated()
		{
			return mLuaState != null;
		}

		void	executeFile(string filePath)
		{
			assert(isCreated());

			string	text;
			text = cast(string)read(filePath);
			execute(text, filePath);
		}

		void	execute(string text, string filePath)
		{
			assert(isCreated());

			//GC.disable();
			//scope(exit) GC.enable();

			lua_pushstring(luaState(), "__This");
			lua_pushlightuserdata(luaState(), cast(void*)this);
			lua_settable(luaState(), LUA_REGISTRYINDEX);

			initializationPhase = true;

			static if (showDebug)
				writeln("CREATE ==================================================================================================");

			if (luaL_loadbuffer(luaState(), cast(const char*)text.ptr, text.length, filePath.toStringz()) != LUA_OK)
			{
				const char* error = lua_tostring(luaState(), -1);
				writeln("DMLEngine.execute: error: " ~ to!(string)(error));
				lua_pop(luaState(), 1);
				assert(false);

				version (release)
				{
					return;
				}
			}

			if (lua_pcall(luaState(), 0, LUA_MULTRET, 0) != LUA_OK)
			{
				const char* error = lua_tostring(luaState(), -1);
				writeln("DMLEngine.execute: error: " ~ to!(string)(error));
				lua_pop(luaState(), 1);
				assert(false);

				version (release)
				{
					return;
				}
			}

			static if (showDebug)
				writeln("INIT ==================================================================================================");
			foreach (key, binding; mVoidToDeclarativeItems)
				binding.executeBindings();
			initializationPhase = false;

			static if (showDebug)
			{
				writeln("DEPENDANCY TREE ==================================================================================================");
				foreach (key, bindingRef; mItemsToItemBindings)
					writefln("%s\n%s", key, shiftRight(bindingRef.iItemBinding.displayDependents(), "\t", 1));
				writeln("=======================================================================================================");
			}
		}

		void	execute(int functionRef)
		{
			lua_rawgeti(luaState(), LUA_REGISTRYINDEX, functionRef);
			if (lua_pcall(luaState(), 0, LUA_MULTRET, 0) != LUA_OK)
			{
				const char* error = lua_tostring(luaState(), -1);
				writeln("DMLEngine.execute: error: " ~ to!(string)(error));
				lua_pop(luaState(), 1);
				assert(false);

				version (release)
				{
					currentlyExecutedBindingRef = -1;
					return;
				}
			}
		}

		package lua_State*	luaState()
		{
			return mLuaState;
		}

		DeclarativeItem	rootItem()
		{
			foreach (key, binding; mVoidToDeclarativeItems)
			{
				if (binding.declarativeItem.parent() is null)
				{
					writeln("rootItem " ~ binding.declarativeItem.id);
					return binding.declarativeItem;
				}
			}
			return null;
		}

		T	itemBinding(T)(string id)
		{
			auto iItemBinding = mIdToDeclarativeItems[id];
			if (iItemBinding !is null)
				return cast(T)(iItemBinding.declarativeItem);
			return null;
		}

		T	getLuaGlobal(T)(string name)
		{
			lua_getglobal(mLuaState, name.toStringz());
			if (lua_isnone(mLuaState, -1) || lua_isnil(mLuaState, -1))
				throw new Exception(format("global \"%s\" is nil\n", name));

			return dquick.script.utils.valueFromLua!T(mLuaState, -1);
		}

		void	setLuaGlobal(T)(string name, T value)
		{
			dquick.script.utils.valueToLua!T(mLuaState, value);
			lua_setglobal(mLuaState, name.toStringz());
		}

		static immutable bool showDebug = 0;
	private:

		struct ItemRefCounting
		{
			dquick.script.i_item_binding.IItemBinding	iItemBinding;
			uint										count;
		}
		ItemRefCounting[DeclarativeItem]	mItemsToItemBindings;
		dquick.script.i_item_binding.IItemBinding[void*]	mVoidToDeclarativeItems;
		dquick.script.i_item_binding.IItemBinding[string]	mIdToDeclarativeItems;
		lua_State*	mLuaState;
		IWindow		mWindow;
		package dquick.script.property_binding.PropertyBinding[]		currentlyExecutedBindingStack;
		string		itemTypeIds;
		package alias TypeTuple!(int, float, string, bool, Object)	propertyTypes;
		package bool	initializationPhase;
		static if (showDebug)
			package int	lvl;
	}

	extern(C)
	{
		private int	luaPanicFunction(lua_State* L)
		{
			try
			{
				const char* error = lua_tostring(L, 1);
				writeln("[DMLEngine] " ~ to!(string)(error));
				lua_pop(L, 1);
				assert(false);

				version(release)
				{
					return 1;
				}
			}
			catch (Throwable e)
			{
				writeln(e.toString());
				return 0;
			}
		}

		private int	createLuaBind(T)(lua_State* L)
		{
			try
			{
				if (lua_gettop(L) != 2)
				{
					writefln("createLuaBind:: too few or too many param, got %d, expected 1\n", lua_gettop(L));
					return 0;
				}
				if (!lua_istable(L, 1))
				{
					writeln("createLuaBind:: the lua value is not a table\n");
					return 0;
				}
				if (!lua_istable(L, 2))
				{
					writeln("createLuaBind:: the lua value is not a table\n");
					return 0;
				}

				lua_pushstring(L, "__This");
				lua_gettable(L, LUA_REGISTRYINDEX);
				DMLEngine	dmlEngine = cast(DMLEngine)lua_touserdata(L, -1);
				lua_pop(L, 1);

				T	itemBinding = new T(dmlEngine);

				/* table is in the stack at index 't' */
				lua_pushnil(L);  /* first key */
				while (lua_next(L, -2) != 0) {
					/* uses 'key' (at index -2) and 'value' (at index -1) */

					if (lua_type(L, -2) == LUA_TSTRING)
					{
						string	key = to!(string)(lua_tostring(L, -2));

						if (key == "id")
						{
							itemBinding.item.id = to!(string)(lua_tostring(L, -1));
						}
						else
						{
							bool	found = false;
							foreach (member; __traits(allMembers, typeof(itemBinding)))
							{
								//writefln("member = %s", member);
								static if (is(typeof(__traits(getMember, itemBinding, member)) : dquick.script.property_binding.PropertyBinding))
								{
									if (key == member)
									{
										found = true;
										__traits(getMember, itemBinding, member).bindingFromLua(L, -1);
										break;
									}
									else if (key == getSignalNameFromPropertyName(member))
									{
										found = true;

										if (lua_isfunction(L, -1))
										{
											__traits(getMember, itemBinding, member).slotLuaReference = luaL_ref(L, LUA_REGISTRYINDEX);
											lua_pushnil(L); // To compensate the value poped by luaL_ref
										}
										else
											writefln("createLuaBind:: Attribute %s is not a function", key);
										break;
									}
								}
							}

							if (found == false)
							{
								auto	propertyName = getPropertyNameFromSignalName(key);
								if (propertyName != "")
								{
									found = true;

									if (lua_isfunction(L, -1))
									{
										dquick.script.virtual_property_binding.VirtualPropertyBinding virtualProperty;
										auto virtualPropertyPtr = (propertyName in itemBinding.virtualProperties);
										if (!virtualPropertyPtr)
										{
											virtualProperty = new dquick.script.virtual_property_binding.VirtualPropertyBinding(itemBinding, propertyName);
											itemBinding.virtualProperties[propertyName] = virtualProperty;
										}
										else
										{
											virtualProperty = *virtualPropertyPtr;
										}
										virtualProperty.slotLuaReference = luaL_ref(L, LUA_REGISTRYINDEX);
										lua_pushnil(L); // To compensate the value poped by luaL_ref
									}
									else
										writefln("createLuaBind:: Attribute %s is not a function", key);
								}
								else
								{
									dquick.script.virtual_property_binding.VirtualPropertyBinding virtualProperty;
									auto virtualPropertyPtr = (key in itemBinding.virtualProperties);
									if (!virtualPropertyPtr)
									{
										virtualProperty = new dquick.script.virtual_property_binding.VirtualPropertyBinding(itemBinding, key);
										itemBinding.virtualProperties[key] = virtualProperty;
									}
									else
									{
										virtualProperty = *virtualPropertyPtr;
									}
									virtualProperty.bindingFromLua(L, -1);
								}
							}
						}
					}
					else if (lua_type(L, -2) == LUA_TNUMBER)
					{
						void*	itemBindingPtr = *(cast(void**)lua_touserdata(L, -1));

						auto	child = itemBindingPtr in dmlEngine.mVoidToDeclarativeItems;
						if (child == null)
						{
							writeln("createLuaBind:: can't find item\n");
							return 0;
						}

						itemBinding.item.addChild(child.declarativeItem);
					}

					/* removes 'value'; keeps 'key' for next iteration */
					lua_pop(L, 1);
				}
				lua_pop(L, 1); // Remove param 1 (table)

				dmlEngine.addObjectBinding!T(itemBinding, itemBinding.item.id);
				lua_getglobal(L, itemBinding.item.id.toStringz());

				return 1;
			}
			catch (Throwable e)
			{
				writeln(e.toString());
				return 0;
			}
		}

		private int	indexLuaBind(T)(lua_State* L)
		{
			try
			{
				if (lua_gettop(L) != 2)
				{
					writefln("indexLuaBind:: too few or too many param, got %d, expected 2\n", lua_gettop(L));
					return 0;
				}
				if (!lua_isuserdata(L, 1))
				{
					writeln("indexLuaBind:: param 1 is not a userdata\n");
					return 0;
				}
				if (!lua_isstring(L, 2))
				{
					writeln("indexLuaBind:: param 2 is not a string\n");
					return 0;
				}

				lua_pushstring(L, "__This");
				lua_gettable(L, LUA_REGISTRYINDEX);
				DMLEngine	dmlEngine = cast(DMLEngine)lua_touserdata(L, -1);
				lua_pop(L, 1);

				void*	itemBindingPtr = *(cast(void**)lua_touserdata(L, 1));
				lua_remove(L, 1);
				string	propertyId = to!(string)(lua_tostring(L, 1));
				lua_remove(L, 1);

				auto	iItemBinding = itemBindingPtr in dmlEngine.mVoidToDeclarativeItems;
				assert(iItemBinding !is null);
				T	itemBinding = cast(T)(*iItemBinding);

				// Search for property binding on the itemBinding
				foreach (member; __traits(allMembers, typeof(itemBinding)))
				{
					static if (is(typeof(__traits(getMember, itemBinding, member)) : dquick.script.property_binding.PropertyBinding))
					{
						if (propertyId == member)
						{
							__traits(getMember, itemBinding, member).valueToLua(L);
							return 1;
						}
					}
				}
				// Search for simple method on the item
				foreach (member; __traits(allMembers, typeof(itemBinding.item)))
				{
					static if (__traits(compiles, isCallable!(__traits(getMember, typeof(itemBinding.item), member))))
					{
						static if (isCallable!(__traits(getMember, typeof(itemBinding.item), member)) && __traits(compiles, luaCallThisD!(member, typeof(itemBinding.item))(itemBinding.item, L, 1)))
						{
							if (propertyId == member)
							{
								// Create a userdata that contains instance void ptr and return it to emulate a method
								// It also contains a metatable for calling
								void*	userData = lua_newuserdata(L, itemBindingPtr.sizeof);
								memcpy(userData, &itemBindingPtr, itemBindingPtr.sizeof);

								// Create metatable
								lua_newtable(L);
								{
									// Call metamethod to instanciate type
									lua_pushstring(L, "__call");
									lua_pushcfunction(L, cast(lua_CFunction)&methodLuaBind!(member, typeof(itemBinding.item)));
									lua_settable(L, -3);
								}
								lua_setmetatable(L, -2);
								return 1;
							}
						}
					}
				}

				auto virtualProperty = (propertyId in itemBinding.virtualProperties);
				if (virtualProperty == null)
					return 0;

				virtualProperty.valueToLua(L);

				return 1;
			}
			catch (Throwable e)
			{
				writeln(e.toString());
				return 0;
			}
		}

		private int	newindexLuaBind(T)(lua_State* L)
		{
			try
			{
				if (lua_gettop(L) != 3)
				{
					writefln("newindexLuaBind:: too few or too many param, got %d, expected 3\n", lua_gettop(L));
					return 0;
				}
				if (!lua_isuserdata(L, 1))
				{
					writeln("newindexLuaBind:: param 1 is not a string\n");
					return 0;
				}
				if (!lua_isstring(L, 2))
				{
					writeln("newindexLuaBind:: param 2 is not a string\n");
					return 0;
				}

				lua_pushstring(L, "__This");
				lua_gettable(L, LUA_REGISTRYINDEX);
				DMLEngine	dmlEngine = cast(DMLEngine)lua_touserdata(L, -1);
				lua_pop(L, 1);

				void*	itemBindingPtr = *(cast(void**)lua_touserdata(L, 1));
				lua_remove(L, 1);
				string	propertyId = to!(string)(lua_tostring(L, 1));
				lua_remove(L, 1);

				auto	iItemBinding = itemBindingPtr in dmlEngine.mVoidToDeclarativeItems;
				assert(iItemBinding !is null);
				T	itemBinding = cast(T)(*iItemBinding);

				bool	found = false;
				foreach (member; __traits(allMembers, typeof(itemBinding)))
				{
					static if (is(typeof(__traits(getMember, itemBinding, member)) : dquick.script.property_binding.PropertyBinding))
					{
						if (propertyId == member)
						{
							found = true;
							__traits(getMember, itemBinding, member).bindingFromLua(L, 1);
							__traits(getMember, itemBinding, member).dirty = true;
							if (dmlEngine.initializationPhase == false)					
								__traits(getMember, itemBinding, member).executeBinding();
							return 1;
						}
					}
				}

				auto virtualProperty = (propertyId in itemBinding.virtualProperties);
				if (virtualProperty)
				{
					virtualProperty.bindingFromLua(L, 1);
					virtualProperty.dirty = true;
					virtualProperty.executeBinding();
					return 1;
				}

				writefln("newindexLuaBind:: Property %s doesn't exist on object %s", propertyId, itemBinding.item);
				return 0;
			}
			catch (Throwable e)
			{
				writeln(e.toString());
				return 0;
			}
		}

		// Handle simple function binding
		private int	functionLuaBind(alias func)(lua_State* L)
		{
			try
			{
				static assert(__traits(isStaticFunction, func), "func must be a function");

				luaCallD!(func)(L, 1);

				return 1;
			}
			catch (Throwable e)
			{
				writeln(e.toString());
				return 0;
			}
		}

		// Handle method binding
		private int	methodLuaBind(string methodName, T)(lua_State* L)
		{
			try
			{
				static assert(isSomeFunction!(__traits(getMember, T, methodName)) &&
							  !__traits(isStaticFunction, __traits(getMember, T, methodName)) &&
								  !isDelegate!(__traits(getMember, T, methodName)),
							  "func must be a method");

				if (lua_gettop(L) < 1)
					throw new Exception(format("too few param, got %d, expected at least 1\n", lua_gettop(L)));
				if (!lua_isuserdata(L, 1))
					throw new Exception("param 1 is not a userdata");

				lua_pushstring(L, "__This");
				lua_gettable(L, LUA_REGISTRYINDEX);
				DMLEngine	dmlEngine = cast(DMLEngine)lua_touserdata(L, -1);
				lua_pop(L, 1);

				void*	itemBindingPtr = *(cast(void**)lua_touserdata(L, 1));
				lua_remove(L, 1);

				auto	iItemBinding = itemBindingPtr in dmlEngine.mVoidToDeclarativeItems;
				assert(iItemBinding !is null);
				dquick.script.item_binding.ItemBinding!T	itemBinding = cast(dquick.script.item_binding.ItemBinding!T)(*iItemBinding);

				int test = lua_gettop(L);
				luaCallThisD!(methodName, T)(itemBinding.item, L, 1);

				return 1;
			}
			catch (Throwable e)
			{
				writeln(e.toString());
				return 0;
			}
		}
	}
}