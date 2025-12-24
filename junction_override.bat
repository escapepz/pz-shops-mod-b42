del /s /q "C:\ZomboidClient1\mods\Shops"
del /s /q "C:\ZomboidClient2\mods\Shops"
del /s /q "C:\Users\PC\Zomboid\mods\Shops"

ROBOCOPY "D:\DATA\2025\ProjectZ-improve\PZ Mods\project-zomboid-studio\Shopsb42.worktrees\original\Shops" "C:\ZomboidClient1\mods\Shops" /E
ROBOCOPY "D:\DATA\2025\ProjectZ-improve\PZ Mods\project-zomboid-studio\Shopsb42.worktrees\original\Shops" "C:\ZomboidClient2\mods\Shops" /E
ROBOCOPY "D:\DATA\2025\ProjectZ-improve\PZ Mods\project-zomboid-studio\Shopsb42.worktrees\original\Shops" "C:\Users\PC\Zomboid\mods\Shops" /E
