-- listings/_index.lua
-- Registry of all item listing files
-- Controls load order and which files to include
-- Format: module path relative to listings/ folder

-- Tab values must match SHOPSB42.Tab constants:
--   "Favorite", "Sell", "All", "Food", "Weapons", "Vehicles", "FirstAid", "Event"
-- To use custom tabs, extend SHOPSB42.Shop.Tab before registration

return {
	"food",
	"weapons",
	"medical",
	"misc/tools",
	"misc/valuables",
}
