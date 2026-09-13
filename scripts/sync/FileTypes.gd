extends RefCounted
class_name FileTypes

const EXTENSIONS: Array[String] = [
	".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tif", ".tiff", ".webp", ".svg", ".heic", ".avif", ".emf",
	".pdf", ".txt", ".rtf", ".odt", ".fodt", ".doc", ".docm", ".docx", ".dot", ".dotm", ".dotx",
	".htm", ".html", ".mht", ".mhtml", ".wps", ".xps",
	".csv", ".dbf", ".dif", ".ods", ".fods", ".prn", ".slk",
	".xls", ".xlsx", ".xlsm", ".xlsb", ".xlt", ".xltm", ".xltx", ".xla", ".xlam", ".xlw",
	".ppt", ".pptx", ".pptm", ".pps", ".ppsx", ".ppsm", ".pot", ".potx", ".potm",
	".ppa", ".ppam", ".odp", ".fodp", ".thmx",
	".odg", ".fodg", ".odf",
	".xml", ".accdb", ".ecf", ".pub",
	".zip", ".rar", ".7z", ".tar", ".gz"
]

const PAYMENT_API_URL := "https://dres-ai.com/clients-api"
const TASKS_BASE_PATH := "tasks"
