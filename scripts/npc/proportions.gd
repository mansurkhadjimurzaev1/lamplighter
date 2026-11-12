class_name Proportions
extends RefCounted
## Пропорции персонажей KayKit ближе к человеческим: голова меньше, ноги, руки и туловище длиннее.
## Масштабы костей задаются один раз — анимации масштаб не меняют (у них только повороты и сдвиги).
## Возвращает, на сколько поднять модель (в единицах модели), чтобы удлинённые ноги не ушли в землю.

const HEAD := 0.6
const LEG := 1.38
const ARM := 1.18
const TORSO := 1.16


static func apply(model: Node3D, head := HEAD, leg := LEG) -> float:
	var list := model.find_children("*", "Skeleton3D", true, false)
	if list.is_empty():
		return 0.0
	var sk: Skeleton3D = list[0]
	# служебная анимация RESET каждый кадр возвращала бы костям масштаб 1 — убираем из неё масштаб
	for ap: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
		ap.deterministic = false
		if ap.has_animation("RESET"):
			var ra := ap.get_animation("RESET")
			for t in range(ra.get_track_count() - 1, -1, -1):
				if ra.track_get_type(t) == Animation.TYPE_SCALE_3D:
					ra.remove_track(t)
	var b := func(n: String) -> int: return sk.find_bone(n)
	var leg_len := 0.0
	var ul: int = b.call("upperleg.l")
	var ft: int = b.call("foot.l")
	if ul >= 0 and ft >= 0:
		leg_len = sk.get_bone_global_rest(ul).origin.y - sk.get_bone_global_rest(ft).origin.y
	# масштаб наследуется дочерними костями: тянем только верхние звенья, а кисти/стопы/голову
	# компенсируем, чтобы они не вытянулись
	var tor := TORSO * 1.04
	var sets := {"spine": Vector3(1, TORSO, 1), "chest": Vector3(1, 1.04, 1),
		"head": Vector3(head, head / tor, head),
		"upperarm.l": Vector3(1, ARM, 1), "upperarm.r": Vector3(1, ARM, 1),
		"wrist.l": Vector3(1, 1.0 / ARM, 1), "wrist.r": Vector3(1, 1.0 / ARM, 1),
		"upperleg.l": Vector3(1, leg, 1), "upperleg.r": Vector3(1, leg, 1),
		"foot.l": Vector3(1, 1.0 / leg, 1), "foot.r": Vector3(1, 1.0 / leg, 1)}
	for n in sets:
		var i: int = b.call(n)
		if i >= 0:
			sk.set_bone_pose_scale(i, sets[n])
	return leg_len * (leg - 1.0)
