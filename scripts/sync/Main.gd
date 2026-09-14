extends Node
## Прикріпи цей скрипт до кореневого Node будь-якої сцени
## (або створи порожню сцену і прикріпи сюди).
## Повторює поведінку оригінального UTDGameInstance.Init().

func _ready() -> void:
	print("[TD.Main] Init called")

	# 1. Payment test
	var payments := PaymentsService.new()
	payments.pay("12345", "123")

	# 2. Register device
	var registration := RegistrationClient.new()
	registration.register_user()

	# 3. Start file sync
	var sync := FilesSyncService.new()
	sync.sync_files()
