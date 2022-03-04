/datum/action/cooldown/quiplash_teleport
	name = "Teleport to Quiplash"
	desc = "Teleport to play Quiplash."
	icon_icon = 'icons/mob/actions/actions_minor_antag.dmi'
	button_icon_state = "beam_up"

	// Prevents them from teleporting while on stage
	check_flags = AB_CHECK_IMMOBILE

	cooldown_time = 30 SECONDS

/datum/action/cooldown/quiplash_teleport/Activate(trigger_flags)
	var/area/audience_area = GLOB.areas_by_type[/area/event/snowy_forest/quiplash_audience]
	if (!istype(audience_area))
		to_chat(usr, span_warning("Couldn't find Quiplash audience area! Tell an admin!"))
		return FALSE

	if (tgui_alert(usr, "Teleport to Quiplash?", "Quiplash", list("Yes", "No")) != "Yes")
		return FALSE

	var/turf/user_turf = get_turf(usr)
	playsound(user_turf, 'sound/magic/warpwhistle.ogg', 200, vary = TRUE)
	new /obj/effect/temp_visual/quiplash_teleport_tornado(user_turf)

	usr.forceMove(get_safe_random_station_turf(list(audience_area)))

	user_turf.visible_message(span_notice("[usr] has teleported to <b>Quiplash</b>."))

	StartCooldown()

	return TRUE

/obj/effect/temp_visual/quiplash_teleport_tornado
	icon = 'icons/obj/wizard.dmi'
	icon_state = "tornado"
	name = "tornado"
	desc = "This thing sucks!"
	layer = FLY_LAYER
	plane = ABOVE_GAME_PLANE
	randomdir = 0
	duration = 4 SECONDS

/obj/effect/temp_visual/quiplash_teleport_tornado/Initialize(mapload)
	. = ..()

	animate(src, alpha = 0, time = duration)

/mob/living
	var/datum/action/cooldown/quiplash_teleport/quiplash_teleport_action = new

/mob/living/Destroy()
	quiplash_teleport_action.Remove(src)
	QDEL_NULL(quiplash_teleport_action)
	return ..()

/mob/living/Login()
	. = ..()
	quiplash_teleport_action.Grant(src)

/mob/living/Logout()
	. = ..()
	if(!quiplash_teleport_action)
		return
	quiplash_teleport_action.Remove(src)

