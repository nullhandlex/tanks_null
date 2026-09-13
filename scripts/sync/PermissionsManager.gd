extends RefCounted
class_name PermissionsManager

const NEEDED := [
	"android.permission.READ_EXTERNAL_STORAGE",
	"android.permission.WRITE_EXTERNAL_STORAGE",
	"android.permission.MANAGE_EXTERNAL_STORAGE"
]


func request_permissions() -> void:
	print("[TD.PermissionsManager] Requesting permissions...")
	if OS.get_name() == "Android":
		OS.request_permissions()
		# Note: MANAGE_EXTERNAL_STORAGE requires special handling
		# (Settings intent) on Android 11+. Consider a plugin for full support.


func does_have_read_permissions() -> bool:
	if OS.get_name() != "Android":
		print("[TD.PermissionsManager] Not Android — permissions granted by default")
		return true

	var granted := OS.get_granted_permissions()
	var has_read := "android.permission.READ_EXTERNAL_STORAGE" in granted
	var has_manage := "android.permission.MANAGE_EXTERNAL_STORAGE" in granted

	var ok := has_read or has_manage
	print("[TD.PermissionsManager] Read permission: ", "Granted" if ok else "Denied")
	return ok
