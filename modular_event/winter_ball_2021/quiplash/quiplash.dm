#define QUIPLASH_PAUSED "paused"
#define QUIPLASH_BETWEEN_ROUNDS "between_rounds"
#define QUIPLASH_ANSWERING "answering"
#define QUIPLASH_VOTING "voting"
#define QUIPLASH_TOMATO_THROWING "tomato_throwing"

#define DEFAULT_GAME_INDEX "A"

#define COMSIG_QUIPLASH_STATUS_UPDATE "quiplash_status_update"

#define PROMPTS_FILE "modular_event/winter_ball_2021/quiplash/quiplash_prompts.txt"

GLOBAL_LIST_EMPTY(quiplash_games)

/datum/quiplash_manager
	/// Current game phase
	var/state = QUIPLASH_PAUSED

	/// Timer to next phase
	var/main_timer

	/// Area instances we track audience in
	var/list/audience_areas = list()
	/// Audience mobs
	var/list/audience_members = list()
	/// Map of ckeys to times they already played, new players get priority to go on stage
	var/list/previous_players = list()
	/// Current players mobs
	var/list/players = list()
	/// Stage spawnpoints not currently in use
	var/list/unassigned_stage_points = list()
	/// Stage points currently in use indexed by player
	var/list/assigned_stage_points = list()
	/// All possible prompts
	var/list/prompts = list("Why did the clown end up in the brig ?", "Place where assistants come from", "First entry on captain's to-do list")
	/// Currently picked prompt
	var/current_prompt
	/// Map of player mob to their answers
	var/list/answers = list()

	/// Mob to voted player
	var/list/votes = list()

	/// Name to win count
	var/list/leaderboard = list()

	/// How long the wait between rounds
	var/between_rounds_time = 30 SECONDS
	/// How long the players get to put in the answers
	var/answer_time = 30 SECONDS
	/// How long to vote
	var/vote_time = 30 SECONDS
	/// How long players stay on stage after result announcement
	var/tomato_throwing_time = 15 SECONDS

	/// Cache of name searching regexes for voting
	var/static/regex_cache = list()

	/// Doesn't check clients
	var/debug_mode = FALSE

	/// Crown effect shown over winners
	var/obj/effect/winner_crown/winner_crown

	/// We dump players back here if we can't find safe audience area turf
	var/turf/fallback_dump_turf

	/// Admin abuse specific prompt here
	var/forced_prompt

	/// sounds and notifications will emit from here
	var/list/message_sources = list()

	/// audience members who opted out of playing
	var/list/opted_out_audience = list()

	///we put audience back from where we picked them up, this tracks the turfs
	var/list/audience_return_point = list()

/datum/quiplash_manager/proc/start()
	set_state(QUIPLASH_BETWEEN_ROUNDS)

/datum/quiplash_manager/proc/pause()
	set_state(QUIPLASH_PAUSED)

/datum/quiplash_manager/proc/reset_game()
	reset_round()

/datum/quiplash_manager/proc/load_prompts()
	prompts = splittext(file2text(PROMPTS_FILE),"\n")

/datum/quiplash_manager/proc/set_state(new_state)
	if(main_timer)
		deltimer(main_timer)
		main_timer = null
	switch(new_state)
		if(QUIPLASH_PAUSED)
			reset_game()
		if(QUIPLASH_ANSWERING)
			if(!choose_players()) // not enough players to start, wait some more
				set_state(QUIPLASH_BETWEEN_ROUNDS)
				return
			pick_prompt_and_start_answering()
			set_timeout(answer_time,QUIPLASH_VOTING)
		if(QUIPLASH_VOTING)
			if(length(answers) != length(players))
				replace_idle_players()
				set_state(QUIPLASH_ANSWERING)
				return
			display_answers()
			show_voting_message_to_audience()
			set_timeout(vote_time,QUIPLASH_TOMATO_THROWING)
		if(QUIPLASH_TOMATO_THROWING)
			display_results()
			set_timeout(tomato_throwing_time,QUIPLASH_BETWEEN_ROUNDS)
		if(QUIPLASH_BETWEEN_ROUNDS)
			reset_round()
			set_timeout(between_rounds_time,QUIPLASH_ANSWERING)
	state = new_state
	for(var/message_source in message_sources)
		playsound(message_source, 'sound/effects/gong.ogg', 100, TRUE)

/datum/quiplash_manager/proc/choose_players(ignored_players)
	. = FALSE
	var/player_count = length(unassigned_stage_points)
	var/list/filtered_audience = list()
	for(var/mob/participant in audience_members)
		if(!participant.client && !debug_mode)
			continue
		if(participant.stat == DEAD || (participant in ignored_players) || (participant.ckey in opted_out_audience)) //Anything else ?
			continue
		filtered_audience += participant
	if(length(filtered_audience) < player_count)
		return FALSE
	var/list/weighted_audience = list()
	var/max_wins = max_assoc_value(previous_players)
	for(var/mob/participant in filtered_audience)
		weighted_audience[participant] = 1 + (max_wins - previous_players[participant.ckey]) //i hate using implicit null conversions like this

	for(var/i in 1 to player_count)
		var/chosen_player = pick_weight(weighted_audience)
		weighted_audience -= chosen_player
		make_player(chosen_player)
	return TRUE

/datum/quiplash_manager/proc/replace_idle_players()
	//We assume players who did not send answer by now are idle
	var/list/idle_players = list()
	for(var/mob/player in players)
		if(answers[player])
			continue
		idle_players += player
		remove_player(player)
	choose_players(idle_players)

/datum/quiplash_manager/proc/make_player(mob/new_player_mob)
	players |= new_player_mob
	previous_players[new_player_mob.ckey] = previous_players[new_player_mob.ckey] + 1
	var/obj/effect/landmark/quiplash_stage_marker/stage_point = pop(unassigned_stage_points)
	stage_point.set_player_name(MAPTEXT("<span class='center'>[new_player_mob.real_name]</span>"))
	assigned_stage_points[new_player_mob] = stage_point
	audience_return_point[new_player_mob] = get_turf(new_player_mob)
	new_player_mob.forceMove(get_turf(stage_point))
	//GIVE THEM EVENT SPEECH ENABLERS
	ADD_TRAIT(new_player_mob, TRAIT_BYPASS_MEASURES, "quiplash")
	ADD_TRAIT(new_player_mob, TRAIT_IMMOBILIZED, "quiplash")

/datum/quiplash_manager/proc/remove_player(mob/player)
	players -= player
	answers -= player
	var/obj/effect/landmark/quiplash_stage_marker/stage_point = assigned_stage_points[player]
	stage_point.set_player_name(null)
	assigned_stage_points -= player
	unassigned_stage_points |= stage_point
	player.forceMove(audience_return_point[player] || get_safe_random_station_turf(audience_areas) || fallback_dump_turf)
	audience_return_point -= player
	//REMOVE EVENT SPEECH ENABLER
	REMOVE_TRAIT(player, TRAIT_IMMOBILIZED, "quiplash")
	REMOVE_TRAIT(player, TRAIT_BYPASS_MEASURES, "quiplash")

/datum/quiplash_manager/proc/show_voting_message_to_audience()
	for(var/mob/living/audience_member in audience_members)
		if(audience_member in players)
			continue
		to_chat(audience_member,span_big(span_boldwarning("Vote for your favourite by saying their name or their answer!")))

/datum/quiplash_manager/proc/display_results()
	var/list/vote_tally = list()
	for(var/mob/voter in votes)
		var/voted = votes[voter]
		vote_tally[voted] = vote_tally[voted] + 1

	var/most_votes = max_assoc_value(vote_tally)
	var/list/winners = list()
	for(var/mob/player in vote_tally)
		if(vote_tally[player] == most_votes)
			winners += player
	var/draw = length(winners) > 1
	for(var/mob/winner in winners)
		if(!draw)
			leaderboard[winner.real_name] = leaderboard[winner.real_name] + 1
		new /obj/effect/temp_visual/confetti(winner.loc)
		if(!winner_crown)
			winner_crown = new(null)
		winner.vis_contents |= winner_crown
		addtimer(CALLBACK(src, .proc/remove_crown, winner), 2 MINUTES)

/datum/quiplash_manager/proc/remove_crown(mob/crown_owner)
	crown_owner.vis_contents -= winner_crown

/datum/quiplash_manager/proc/reset_round()
	for(var/mob/player in players)
		remove_player(player)
	for(var/obj/effect/landmark/quiplash_stage_marker/spot in unassigned_stage_points)
		spot.set_maptext(null)
	current_prompt = null
	answers = list()
	votes = list()
	SEND_SIGNAL(src, COMSIG_QUIPLASH_STATUS_UPDATE)
	return

/datum/quiplash_manager/proc/parse_prompt(raw_prompt)
	var/resulting_prompt = raw_prompt
	if(findtext(resulting_prompt,"<ANYPLAYER>")) //replace anyplayer with name of someone from previous rounds
		var/random_name = "Unknown"
		if(length(previous_players))
			var/ckey = pick(previous_players)
			var/client/client = GLOB.directory[ckey]
			if(client && client.mob)
				random_name = client.mob.real_name
		resulting_prompt = replacetext(resulting_prompt,"<ANYPLAYER>",random_name)
	resulting_prompt = replacetext(resulting_prompt,"<BLANK>","_______")
	return resulting_prompt

/datum/quiplash_manager/proc/pick_prompt_and_start_answering()
	current_prompt = parse_prompt(forced_prompt || pick(prompts))
	if(forced_prompt)
		forced_prompt = null
	SEND_SIGNAL(src,COMSIG_QUIPLASH_STATUS_UPDATE)
	for(var/mob/player in players)
		if(!player.client)
			set_answer(player, pick("Yo mamma","My ass"))
			continue
		tgui_input_text_async(player, "[current_prompt]", "Write your answer!", "", callback = CALLBACK(src,.proc/answer_made), timeout = answer_time)

/datum/quiplash_manager/proc/display_answers()
	log_game("Quiplash Question: [current_prompt]")
	//Display answers over player spots
	for(var/mob/player in players)
		var/obj/effect/landmark/quiplash_stage_marker/spot = assigned_stage_points[player]
		var/answer = answers[player]
		spot.set_maptext(MAPTEXT("<span class='center'>[answer]</span>"))
		log_game("Quiplash Answer: [answer] by [key_name(player)]")

/datum/quiplash_manager/proc/answer_made(answer)
	var/mob/user = usr
	if(!(user in players))
		return
	if(state != QUIPLASH_ANSWERING)
		return
	set_answer(user, answer)

/datum/quiplash_manager/proc/set_answer(user, answer)
	answers[user] = answer
	if(length(answers) == length(players)) // Everyone answered, skip to voting
		set_state(QUIPLASH_VOTING)

/// Returns maximum assoc value
/proc/max_assoc_value(list/L)
	var/max_value
	for(var/key in L)
		if(L[key] > max_value)
			max_value = L[key]
	return max_value

/datum/quiplash_manager/proc/add_stage_spot(obj/effect/landmark/quiplash_stage_marker/spot)
	unassigned_stage_points |= spot
	return

/datum/quiplash_manager/proc/set_timeout(delay,next_state)
	if(main_timer)
		deltimer(main_timer)
		main_timer = null
	main_timer = addtimer(CALLBACK(src, .proc/set_state, next_state), delay, TIMER_STOPPABLE)

/datum/quiplash_manager/proc/add_audience_area(area/new_area)
	audience_areas += new_area
	RegisterSignal(new_area,COMSIG_AREA_ENTERED,.proc/audience_area_entered)
	//add people currently in the area to the audience

/datum/quiplash_manager/proc/audience_area_entered(source,mover)
	SIGNAL_HANDLER
	if(isliving(mover))
		add_audience_member(mover)

/datum/quiplash_manager/proc/add_audience_member(mob/new_audience_member)
	to_chat(new_audience_member,span_notice("You're now part of the audience."))
	audience_members |= new_audience_member
	RegisterSignal(new_audience_member,COMSIG_MOB_SAY, .proc/listen_to_vote)
	RegisterSignal(new_audience_member,COMSIG_EXIT_AREA, .proc/audience_member_left_area)
	RegisterSignal(new_audience_member,COMSIG_PARENT_QDELETING, .proc/audience_member_deleted)
	var/datum/action/quiplash_opt_out/opt_out_action = new
	opt_out_action.game = src
	opt_out_action.Grant(new_audience_member)


/datum/quiplash_manager/proc/audience_member_left_area(datum/source, area/area_left)
	SIGNAL_HANDLER
	remove_audience_member(source)

/datum/quiplash_manager/proc/audience_member_deleted(atom/movable/source, force) //Technically this is optional since null move in destroy should do this anyway but still
	SIGNAL_HANDLER
	remove_audience_member(source)

/datum/quiplash_manager/proc/remove_audience_member(mob/audience_member)
	to_chat(audience_member,span_notice("You're no longer part of the audience."))
	audience_members -= audience_member
	UnregisterSignal(audience_member,list(COMSIG_MOB_SAY,COMSIG_EXIT_AREA,COMSIG_PARENT_QDELETING))
	for(var/datum/action/quiplash_opt_out/opt_out_action in audience_member.actions)
		qdel(opt_out_action)

/datum/quiplash_manager/proc/listen_to_vote(datum/source, list/speech_args)
	SIGNAL_HANDLER
	if(state != QUIPLASH_VOTING)
		return FALSE
	var/mob/speaker = source
	var/message = speech_args[SPEECH_MESSAGE]
	if(!debug_mode && (source in players)) //Players can't vote
		return FALSE
	for(var/mob/player in players)
		if(message_contains_identifier(message,player))
			votes[speaker] = player
			to_chat(source,span_boldwarning("Your vote for [player] was registered."))
			break
	return FALSE

/datum/quiplash_manager/proc/message_contains_identifier(message,mob/player)
	var/regex/search_regex
	var/basic_name = player.real_name
	if(regex_cache[basic_name])
		search_regex = regex_cache[basic_name]
	else
		var/first_name = REGEX_QUOTE(player.first_name())
		var/last_name = REGEX_QUOTE(player.last_name())
		var/simplified_name = REGEX_QUOTE(simplify_name(basic_name))
		regex_cache[basic_name] = search_regex = regex("[basic_name]|[first_name]|[last_name]|[simplified_name]|[lizardify_message(basic_name)]|[lizardify_message(first_name)]|[lizardify_message(last_name)]|[lizardify_message(simplified_name)]", "i")
	if(findtext(message,search_regex))
		return TRUE
	var/answer = answers[player]
	if(findtext(message,answer))
		return TRUE
	return FALSE

/datum/quiplash_manager/proc/lizardify_message(message)
	if(!message)
		return
	var/static/regex/lizard_hiss = new("s+", "g")
	var/static/regex/lizard_hiSS = new("S+", "g")
	var/static/regex/lizard_kss = new(@"(\w)x", "g")
	var/static/regex/lizard_kSS = new(@"(\w)X", "g")
	var/static/regex/lizard_ecks = new(@"\bx([\-|r|R]|\b)", "g")
	var/static/regex/lizard_eckS = new(@"\bX([\-|r|R]|\b)", "g")
	if(message[1] != "*")
		message = lizard_hiss.Replace(message, "sss")
		message = lizard_hiSS.Replace(message, "SSS")
		message = lizard_kss.Replace(message, "$1kss")
		message = lizard_kSS.Replace(message, "$1KSS")
		message = lizard_ecks.Replace(message, "ecks$1")
		message = lizard_eckS.Replace(message, "ECKS$1")
	return message

/datum/quiplash_manager/proc/simplify_name(name)
	//name with anything but letters and spaces removed
	var/static/regex/simplify_regex = regex(@"[^a-zA-Z ]","g")
	return simplify_regex.Replace(name,"")


/datum/quiplash_manager/proc/init_landmarks(game_index)
	for(var/obj/effect/landmark/quiplash_stage_marker/spot in GLOB.landmarks_list)
		if(spot.game_index == game_index)
			add_stage_spot(spot)

/obj/structure/quiplash_statue
	name = "Quiplash"
	icon = 'icons/obj/statue.dmi'
	icon_state = "clown"
	anchored = TRUE
	density = TRUE

	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

	maptext_height = 64
	maptext_width = 256
	maptext_x = -128 + 16
	maptext_y = 35

	plane = GAME_PLANE_UPPER
	layer = ABOVE_MOB_LAYER

	var/game_index = DEFAULT_GAME_INDEX
	var/audience_area
	var/datum/quiplash_manager/game

/obj/structure/quiplash_statue/Initialize(mapload)
	. = ..()
	if(GLOB.quiplash_games[game_index])
		game = GLOB.quiplash_games[game_index]
		game.message_sources |= src
	else
		game = new
		var/area/audience_area_instance
		if(!audience_area)
			audience_area_instance = get_area(src);
		else
			audience_area_instance = get_area_instance_from_text(audience_area)
		game.add_audience_area(audience_area_instance)
		game.init_landmarks(game_index)
		game.fallback_dump_turf = get_turf(src)
		game.message_sources |= src
		game.load_prompts()
		GLOB.quiplash_games[game_index] = game

	RegisterSignal(game,COMSIG_QUIPLASH_STATUS_UPDATE,.proc/update_status_display)

	START_PROCESSING(SSfastprocess, src) //countdown updates

/obj/structure/quiplash_statue/process(delta_time)
	update_status_display()

/obj/structure/quiplash_statue/proc/update_status_display()
	var/time_left = game.main_timer ? "[round(timeleft(game.main_timer)/10)]s" : ""
	var/statetext = "HUH?"
	switch(game.state)
		if(QUIPLASH_BETWEEN_ROUNDS)
			statetext = "NEXT ROUND IN: "
		if(QUIPLASH_PAUSED)
			statetext = "GAME ON HOLD"
		if(QUIPLASH_ANSWERING)
			statetext = "WRITE YOUR RESPONSE: "
		if(QUIPLASH_VOTING)
			statetext = "VOTE FOR THE BEST: "
		if(QUIPLASH_TOMATO_THROWING)
			statetext = "CONGRATULATIONS TO THE WINNER: "
	var/prompt_text = game.current_prompt ? "<br><font color='red'>[game.current_prompt]</font>" : "" //fix the centering
	var/display_prompt = "<span class='center'>[statetext][time_left][prompt_text]</span>"
	maptext = MAPTEXT("[display_prompt]")


/obj/structure/quiplash_statue/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "Quiplash", name)
		ui.open()

/obj/structure/quiplash_statue/ui_data(mob/user)
	. = ..()
	.["state"] = game.state
	.["admin"] = user.client.holder ? TRUE : FALSE
	.["leaderboard"] = game.leaderboard

/obj/structure/quiplash_statue/ui_state(mob/user)
	. = ..()
	if(user.client.holder)
		return GLOB.admin_state

/obj/structure/quiplash_statue/ui_act(action, params)
	. = ..()
	if(!usr.client.holder)
		return
	switch(action)
		if("pause")
			if(game.state == QUIPLASH_PAUSED)
				game.start()
			else
				game.pause()
			return TRUE
		if("force_prompt")
			game.forced_prompt = tgui_input_text(usr,"Enter your forced prompt","Force prompt", encode = FALSE)
			return TRUE

/// Players get teleported here
/obj/effect/landmark/quiplash_stage_marker
	name = "quiplash stage"
	icon = 'modular_event/winter_ball_2021/quiplash/quiplash.dmi'
	icon_state = "mic"
	invisibility = 0
	// Player prompts gets displayed on these

	plane = GAME_PLANE_UPPER
	layer = ABOVE_MOB_LAYER + 0.1
	pixel_y = -5 //change this when sprite changes

	var/game_index = DEFAULT_GAME_INDEX

	var/obj/effect/maptext_holder/text_holder
	var/obj/effect/maptext_holder/bottom/name_holder

/obj/effect/landmark/quiplash_stage_marker/Initialize(mapload)
	. = ..()
	text_holder = new(null)
	name_holder = new(null)
	vis_contents += text_holder
	vis_contents += name_holder

/obj/effect/landmark/quiplash_stage_marker/proc/set_maptext(answer_text)
	text_holder.maptext = answer_text

/obj/effect/landmark/quiplash_stage_marker/proc/set_player_name(player_name)
	name_holder.maptext = player_name

/// Crown displayed over the winner
/obj/effect/winner_crown
	name = "WINNER"
	desc = "Winner below"
	icon = 'modular_event/winter_ball_2021/quiplash/quiplash.dmi'
	icon_state = "crown"
	pixel_y = 28
	plane = GAME_PLANE_UPPER
	layer = ABOVE_MOB_LAYER
	vis_flags = NONE
	var/filter_time = 4000

/obj/effect/winner_crown/Initialize(mapload)
	. = ..()
	add_filter("crown_rays", 3, list("type" = "rays", "size" = 28, "color" = COLOR_VIVID_YELLOW))
	animate(filters[1], offset = 1000, time = filter_time, loop = -1)
	animate(offset = 0, loop = -1)


/obj/effect/temp_visual/confetti
	icon = 'modular_event/winter_ball_2021/quiplash/quiplash.dmi'
	icon_state = "confetti" //replace with confetti temp visual
	duration = 30

/// This is here so prompts/answers go above runechat text so they're never obscured by players talking
/obj/effect/maptext_holder
	plane = RUNECHAT_PLANE
	vis_flags = VIS_INHERIT_ID

	maptext_width = 256
	maptext_x = -128 + 16
	maptext_y = 48 // above player and leaving a bit of space for one line of chat messages

/// Player name under
/obj/effect/maptext_holder/bottom
	maptext_y = -18 // below player


/datum/action/quiplash_opt_out
	name = "Opt out of playing"
	desc = "Press this if you do not want to be a player and just observe."
	button_icon_state = "vote"
	var/datum/quiplash_manager/game

/datum/action/quiplash_opt_out/Trigger(trigger_flags)
	. = ..()
	if(!.)
		return
	if(owner.ckey in game.opted_out_audience)
		game.opted_out_audience -= owner.ckey
		to_chat(owner,"You will again be considered for the game.")
	else
		game.opted_out_audience += owner.ckey
		to_chat(owner,"You will now be ignored when picking out players for the game. Press this button again to turn this off.")
