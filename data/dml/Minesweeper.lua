Image {
	id = "root",
	status = function()
		return 10
	end,	
	onStatusChanged = function()
		print(status)
	end,
}

