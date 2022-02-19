/obj/effect/cornfield
	name = "cornfield"
	desc = "just a cornfield..."
	plane = GAME_PLANE_UPPER
	layer = ABOVE_MOB_LAYER
	icon = 'modular_event/winter_ball_2021/corn/corn.dmi'
	icon_state = "corn"

/obj/effect/cornfield/Initialize(mapload)
	. = ..()
	RegisterSignal(loc,COMSIG_ATOM_ENTERED, .proc/Sway)

/obj/effect/cornfield/proc/Sway(datum/source, atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	SIGNAL_HANDLER
	if(isliving(arrived) || istype(arrived,/obj/effect/cornfield_monster))
		flick("corn_disturbed",src)


/obj/effect/cornfield_monster
	name = "cornfield monster"
	invisibility = INVISIBILITY_ABSTRACT
	icon = 'modular_event/winter_ball_2021/corn/corn.dmi'
	icon_state = "monster"

	/// Decides which path points we'll use
	var/monster_id = "A"

	/// List of landmarks we travel towards, debug purpose
	var/list/path

	var/move_delay = 5


/obj/effect/cornfield_monster/Initialize(mapload)
	. = ..()
	var/obj/effect/landmark/cornfield_monster_path_point/start_point = new(loc)
	start_point.monster_id = monster_id
	start_point.index = 0

	update_patrol()

/obj/effect/cornfield_monster/Moved(atom/OldLoc, Dir)
	. = ..()
	var/obj/effect/landmark/cornfield_monster_drop_point/drop_point
	for(var/mob/living/lunch in loc)
		to_chat(lunch,span_userdanger("SOMETHING IS IN HERE..."))
		lunch.SetSleeping(30)
		if(!drop_point)
			for(var/obj/effect/landmark/cornfield_monster_drop_point/point in GLOB.landmarks_list)
				if(point.monster_id == monster_id)
					drop_point = point
					break
		if(drop_point)
			lunch.forceMove(get_turf(drop_point))

/obj/effect/cornfield_monster/proc/update_patrol()
	var/list/patrol_points = get_patrol_points()
	SSmove_manager.move_to_patrol(src, patrol_points, delay = move_delay)

/obj/effect/cornfield_monster/proc/get_patrol_points()
	var/list/points = list()
	for(var/obj/effect/landmark/cornfield_monster_path_point/mark in GLOB.landmarks_list)
		if(mark.monster_id != monster_id)
			continue
		points += mark
	path = sortTim(points, cmp=/proc/cmp_path_point_by_index_asc)

	var/list/point_turfs = list()
	for(var/obj/effect/landmark/cornfield_monster_path_point/mark in path)
		point_turfs += get_turf(mark)
	return point_turfs

/proc/cmp_path_point_by_index_asc(obj/effect/landmark/cornfield_monster_path_point/A, obj/effect/landmark/cornfield_monster_path_point/B)
	return A.index - B.index

/// Place these with sequential index to make up corn monster path with given id, after last it goes back to it's spawn point
/obj/effect/landmark/cornfield_monster_path_point
	name = "cornfield monster path point"
	invisibility = INVISIBILITY_ABSTRACT
	var/monster_id = "A"
	var/index = 1

/// This is where the monster will drop people it catches
/obj/effect/landmark/cornfield_monster_drop_point
	name = "cornfield monster drop point"
	invisibility = INVISIBILITY_ABSTRACT
	var/monster_id = "A"

/datum/controller/subsystem/move_manager/proc/move_to_patrol(moving, list/patrol_points , min_dist, delay, timeout, subsystem, priority, flags, datum/extra_info)
	return add_to_loop(moving, subsystem, /datum/move_loop/has_target/dist_bound/move_to/patrol, priority, flags, extra_info, delay, timeout, patrol_points[1], min_dist, patrol_points)


/datum/move_loop/has_target/dist_bound/move_to/patrol
	var/list/patrol_points

/datum/move_loop/has_target/dist_bound/move_to/patrol/setup(delay, timeout, atom/chasing, dist, list/patrol_points)
	. = ..()
	if(!.)
		return
	src.patrol_points = patrol_points


/datum/move_loop/has_target/dist_bound/move_to/patrol/move()
	. = ..()
	if(moving.loc == target)
		target = patrol_points[WRAP(patrol_points.Find(target)+1,1,length(patrol_points)+1)]

