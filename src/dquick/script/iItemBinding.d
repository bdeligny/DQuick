module dquick.script.i_item_binding;

import dquick.item.declarative_item;
import dquick.script.dml_engine_core;

interface IItemBinding {
	dquick.script.dml_engine_core.DMLEngineCore	dmlEngine();
	void										dmlEngine(dquick.script.dml_engine_core.DMLEngineCore);
	DeclarativeItem	declarativeItem();
	void	executeBindings();
	string	displayDependents();
	bool	creating();
}
