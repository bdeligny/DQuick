module dquick.script.propertyBinding;

import std.algorithm;
import std.file, std.stdio;
import std.conv;
import std.string;
import std.array;

import derelict.lua.lua;

import dquick.script.dmlEngine;
import dquick.script.iItemBinding;

class PropertyBinding
{
	int	_slotLuaReference = -1;
	void	slotLuaReference(int luaRef)
	{
		if (_slotLuaReference != -1)
			luaL_unref(itemBinding.dmlEngine.luaState(), LUA_REGISTRYINDEX, _slotLuaReference);
		_slotLuaReference = luaRef;
	}
	int		slotLuaReference()
	{
		return _slotLuaReference;
	}

	int	_luaReference = -1;
	void	luaReference(int luaRef)
	{
		if (_luaReference != -1)
			luaL_unref(itemBinding.dmlEngine.luaState(), LUA_REGISTRYINDEX, _luaReference);
		_luaReference = luaRef;
		if (_luaReference != -1)
		{
			// Load env lookup function to handle this and parent
			string	lua = q"(
				__item_index = function (_, n)
					if n == "this" then
						return rawget(_, n)
					else 
						local itemMemberVal = rawget(_, "this")[n];
						if itemMemberVal == nil then
							return _ENV[n]
						else
							return itemMemberVal
						end
					end
				end
				__item_newindex = function (_, n, v)
					assert(n ~= "this")
					local this = rawget(_, "this")
					if this[n] == nil then
						_ENV[n] = v
					else
						this[n] = v
					end
				end
			)";
			itemBinding.dmlEngine.load(lua, "");
			itemBinding.dmlEngine.execute();

			lua_rawgeti(itemBinding.dmlEngine.luaState(), LUA_REGISTRYINDEX, _luaReference);

			// Create new _ENV table
			lua_newtable(itemBinding.dmlEngine.luaState());

			// this global
			lua_pushstring(itemBinding.dmlEngine.luaState(), "this");
			itemBinding.pushToLua(itemBinding.dmlEngine.luaState());
			lua_settable(itemBinding.dmlEngine.luaState(), -3);

			// Create new _ENV's metatable
			lua_newtable(itemBinding.dmlEngine.luaState());
			{
				{
					// __index metamethod to chain lookup to the parent env
					lua_pushstring(itemBinding.dmlEngine.luaState(), "__index");
					lua_getglobal(itemBinding.dmlEngine.luaState(), "__item_index");

					// Put component env
					lua_rawgeti(itemBinding.dmlEngine.luaState(), LUA_REGISTRYINDEX, itemBinding.dmlEngine.mEnvStack[itemBinding.dmlEngine.mEnvStack.length - 1]);
					const char*	envUpvalue = lua_setupvalue(itemBinding.dmlEngine.luaState(), -2, 1);
					if (envUpvalue == null) // No access to env, env table is still on the stack so we need to pop it
						lua_pop(itemBinding.dmlEngine.luaState(), 1);

					lua_settable(itemBinding.dmlEngine.luaState(), -3);
				}

				{
					// __newindex metamethod to chain assign to the parent env
					lua_pushstring(itemBinding.dmlEngine.luaState(), "__newindex");
					lua_getglobal(itemBinding.dmlEngine.luaState(), "__item_newindex");

					// Put component env
					lua_rawgeti(itemBinding.dmlEngine.luaState(), LUA_REGISTRYINDEX, itemBinding.dmlEngine.mEnvStack[itemBinding.dmlEngine.mEnvStack.length - 1]);
					const char*	envUpvalue = lua_setupvalue(itemBinding.dmlEngine.luaState(), -2, 1);
					if (envUpvalue == null) // No access to env, env table is still on the stack so we need to pop it
						lua_pop(itemBinding.dmlEngine.luaState(), 1);

					lua_settable(itemBinding.dmlEngine.luaState(), -3);
				}
			}
			lua_setmetatable(itemBinding.dmlEngine.luaState(), -2);

			// Set table to _ENV upvalue
			const char*	envUpvalue = lua_setupvalue(itemBinding.dmlEngine.luaState(), -2, 1);
			if (envUpvalue == null) // No access to env, env table is still on the stack so we need to pop it
				lua_pop(itemBinding.dmlEngine.luaState(), 1);

			lua_pop(itemBinding.dmlEngine.luaState(), 1);
		}
	}
	int		luaReference()
	{
		return _luaReference;
	}

	PropertyBinding[]	dependencies;
	PropertyBinding[]	dependents;

	byte	dirty;

	dquick.script.iItemBinding.IItemBinding itemBinding;

	string	propertyName;
	this(IItemBinding itemBinding, string propertyName)
	{
		this.itemBinding = itemBinding;
		this.propertyName = propertyName;
		dirty = true;
	}
	string	displayDependents()
	{
		string	result;
		/*foreach (dependent; dependents)
		{
			result ~= format("%s.%s\n", itemBinding.id, dependent.propertyName);
		}*/
		return result;
	}

	void	executeBinding()
	{
		if (dirty == false)
			return;

		if (luaReference != -1)
		{
			// Binding overflow or property binding loop detection
			if (itemBinding.dmlEngine.currentlyExecutedBindingStack.length >= 50)
			{
				string	bindingLoopCallStack;
				int	loopCount = 0;
				for (int index = cast(int)(itemBinding.dmlEngine.currentlyExecutedBindingStack.length - 1);  index >= 0; index--)
				{
					//bindingLoopCallStack ~= itemBinding.dmlEngine.currentlyExecutedBindingStack[index].itemBinding.declarativeItem.id;
					bindingLoopCallStack ~= ".";
					bindingLoopCallStack ~= itemBinding.dmlEngine.currentlyExecutedBindingStack[index].propertyName;
					bindingLoopCallStack ~= "\n";
					if (itemBinding.dmlEngine.currentlyExecutedBindingStack[index] == this)
					{
						loopCount++;
						if (loopCount == 2)
							break;
					}
				}
				if (loopCount != 0)
					writefln("DMLEngine.IItemBinding.PropertyBinding.executeBinding: property binding loop detected, callstack:\n%s...", bindingLoopCallStack);
				else
					writeln("DMLEngine.IItemBinding.PropertyBinding.executeBinding: error, binding stack overflow (more than 50)");
				return;
			}

			static if (dquick.script.dmlEngine.DMLEngine.showDebug)
			{
				writefln("%s%s.%s.executeBinding {", replicate("|\t", itemBinding.dmlEngine.lvl++), itemBinding.declarativeItem.id, propertyName);
				scope(exit)
				{
					itemBinding.dmlEngine.lvl--;
					writefln("%s}", replicate("|\t", itemBinding.dmlEngine.lvl));
				}
			}

			foreach (dependency; dependencies)
			{
				for (int index = 0; index < cast(int)dependency.dependents.length; index++)
				{
					if (dependency.dependents[index] == this)
					{
						dependency.dependents = remove(dependency.dependents, index);
						index--;
					}
				}
			}

			dependencies.clear();

			itemBinding.dmlEngine.currentlyExecutedBindingStack ~= this;

			//writefln("%sinitializationPhase = %d executeBinding %s", repeat("|\t", lvl), initializationPhase, item.id);
			//writefln("top = %d", lua_gettop(luaState()));

			int	top = lua_gettop(itemBinding.dmlEngine.luaState());
			lua_rawgeti(itemBinding.dmlEngine.luaState(), LUA_REGISTRYINDEX, luaReference);
			if (lua_pcall(itemBinding.dmlEngine.luaState(), 0, LUA_MULTRET, 0) != LUA_OK)
			{
				version (release)
				{
					currentlyExecutedBindingStack.length--;
					dependencies.clear();
					return;
				}

				string error = to!(string)(lua_tostring(itemBinding.dmlEngine.luaState(), -1));
				lua_pop(itemBinding.dmlEngine.luaState(), 1);
				throw new Exception(format("lua_pcall error: %s", error));
			}
			scope(exit) lua_pop(itemBinding.dmlEngine.luaState(), lua_gettop(itemBinding.dmlEngine.luaState()) - top);

			static if (dquick.script.dmlEngine.DMLEngine.showDebug)
			{
				foreach (dependency; dependencies)
					writefln("%s dependent of %s.%s", replicate("|\t", itemBinding.dmlEngine.lvl), itemBinding.declarativeItem.id, dependency.propertyName);
			}
			foreach (dependency; dependencies)
				dependency.dependents ~= this;

			itemBinding.dmlEngine.currentlyExecutedBindingStack.length--;

			if (lua_gettop(itemBinding.dmlEngine.luaState()) - top != 1)
			{
				writefln("executeBinding:: too few or too many return values, got %d, expected 1\n", lua_gettop(itemBinding.dmlEngine.luaState()) - top);
				return;
			}
			valueFromLua(itemBinding.dmlEngine.luaState(), -1, true);
		}
	}

	void	onChanged()
	{
		dirty = false;
		if (itemBinding.creating == false && slotLuaReference != -1)
			itemBinding.dmlEngine.execute(slotLuaReference);
		if (itemBinding.dmlEngine && itemBinding.dmlEngine.initializationPhase == false)
		{
			static if (dquick.script.dmlEngine.DMLEngine.showDebug)
			{
				writefln("%s%s.%s.onChanged {", replicate("|\t", itemBinding.dmlEngine.lvl++), itemBinding.declarativeItem.id, propertyName);
				scope(exit)
				{
					itemBinding.dmlEngine.lvl--;
					writefln("%s}", replicate("|\t", itemBinding.dmlEngine.lvl));
				}
			}

			auto dependentsCopy = dependents.dup;
			foreach (dependent; dependentsCopy)
			{
				dependent.dirty = true;
				dependent.executeBinding();
			}
		}
	}

	void	valueFromLua(lua_State* L, int index, bool popFromStack = false)
	{
	}

	void	valueToLua(lua_State* L)
	{
		executeBinding();
		//writefln("id = %s", declarativeItem.id);
		// Register acces to value for property binding auto update
		//if (currentlyExecutedBindingStack.length > 100)
		//	writefln("currentlyExecutedBindingStack.length = %d", currentlyExecutedBindingStack.length);

		if (itemBinding.dmlEngine.currentlyExecutedBindingStack.length > 0)
		{
			assert(itemBinding.dmlEngine.currentlyExecutedBindingStack[itemBinding.dmlEngine.currentlyExecutedBindingStack.length - 1] != this);
			itemBinding.dmlEngine.currentlyExecutedBindingStack[itemBinding.dmlEngine.currentlyExecutedBindingStack.length - 1].dependencies ~= this;
		}
	}

	void	bindingFromLua(lua_State* L, int index)
	{
		if (lua_isfunction(L, index)) // Binding is a lua function
		{
			luaReference = luaL_ref(L, LUA_REGISTRYINDEX);
			lua_pushnil(L); // To compensate the value poped by luaL_ref
		}
		else // Binding is juste a value
		{
			luaReference = -1;
			valueFromLua(L, index);
		}
	}
}

