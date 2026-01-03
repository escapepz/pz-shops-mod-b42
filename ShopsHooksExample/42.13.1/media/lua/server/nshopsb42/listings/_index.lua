-- listings/_index.lua
-- Registry of all item listing files
-- Controls load order and which files to include
-- Format: module path relative to listings/ folder

-- Tab values must match SHOPSB42.Tab constants:
--   "Food", "Weapons", "FirstAid", "Event"
-- To use custom tabs, extend SHOPSB42.Shop.Tab before registration

return {
	"Food",
	"Weapons",
	-- "Vehicles", -- pinkslip is not ready in B42 MP yet
	"FirstAid",
	"Event",
	"misc/tools",
	"misc/valuables",
}
