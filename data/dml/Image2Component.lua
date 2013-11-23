GraphicItem {
	id = "comproot",
	x = function()
		return col * width
	end,
	y = function()
		--print(comproot.myId)
		--print(row * height)
		return row * height
	end,	
	width = function()
		return root.width / total
	end,
	height = function()
		return root.height / total
	end,
	source = "images/Alpha-blue-trans.png",
}