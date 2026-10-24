extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		printerr('FAIL: '+label)
func _initialize():
	StoryV24Tests.run(self)
	StoryV25Tests.run(self)
	OnlineV22Tests.run(self)
	print('FOCUSED: ',checks,' checks ',failures,' failures')
	quit(1 if failures else 0)
