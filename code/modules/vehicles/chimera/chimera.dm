#define STATE_TUGGED "tugged"
#define STATE_STOWED "grounded"
#define STATE_DEPLOYED "deployed"
#define STATE_TAKEOFF_LANDING "takeoff_landing"
#define STATE_VTOL "vtol"
#define STATE_FLIGHT "flight"

/obj/vehicle/multitile/chimera
	name = "AD-19D chimera"
	desc = "Get inside to operate the vehicle."
	icon = 'icons/obj/vehicles/chimera.dmi'
	icon_state = "stowed"

	bound_width = 96
	bound_height = 96

	pixel_x = -64
	pixel_y = -32

	bound_x = -32
	bound_y = 0

	interior_map = /datum/map_template/interior/chimera

	move_max_momentum = 2.2
	move_momentum_build_factor = 1.5
	move_turn_momentum_loss_factor = 0.8

	vehicle_light_power = 4
	vehicle_light_range = 5

	vehicle_flags = VEHICLE_CLASS_LIGHT

	vehicle_ram_multiplier = VEHICLE_TRAMPLE_DAMAGE_APC_REDUCTION

	hardpoints_allowed = list(
		/obj/item/hardpoint/locomotion/arc_wheels,
	)

	entrances = list(
		"left" = list(2, 1),
		"right" = list(-2, 1),
		"back" = list(0, 3),
	)

	seats = list(
		VEHICLE_DRIVER = null,
	)

	active_hp = list(
		VEHICLE_DRIVER = null,
	)

	var/image/thrust_overlay

	var/last_turn = 0
	var/turn_delay = 1 SECONDS

	var/state = STATE_STOWED

	var/last_flight_sound = 0
	var/flight_sound_cooldown = 4 SECONDS

	var/obj/chimera_shadow/shadow_holder

	var/busy = FALSE

	var/fuel = 30
	var/max_fuel = 300

/obj/chimera_shadow
	icon = 'icons/obj/vehicles/chimera.dmi'
	pixel_x = -64
	pixel_y = -160
	layer = ABOVE_MOB_LAYER

/obj/vehicle/multitile/chimera/Initialize(mapload, ...)
	. = ..()
	add_hardpoint(new /obj/item/hardpoint/locomotion/arc_wheels)
	shadow_holder = new(src)
	update_icon()

/obj/vehicle/multitile/chimera/Destroy()
	QDEL_NULL(shadow_holder)

	. = ..()

/obj/vehicle/multitile/chimera/update_icon()
	. = ..()

	switch (state)
		if(STATE_VTOL, STATE_TAKEOFF_LANDING)
			icon_state = "vtol"
			overlays += image(icon, "vtol_thrust")
			overlays += image(icon, "fan-overlay")
			overlays += image(icon, "flight_lights")
		if(STATE_FLIGHT)
			icon_state = "flight"
			overlays += image(icon, "fan-overlay")
			overlays += image(icon, "flight_lights")
		if(STATE_STOWED)
			icon_state = "stowed"
			overlays += image(icon, "stowed_lights")
		if(STATE_DEPLOYED)
			icon_state = "flight"
			overlays += image(icon, "stowed_lights")
		if(STATE_TUGGED)
			icon_state = "stowed"
			overlays += image(icon, "stowed_lights")
			overlays += image(icon, "tug_underlay", layer = BELOW_MOB_LAYER)

	if(shadow_holder)
		shadow_holder.icon_state = "[icon_state]_shadow"

/obj/vehicle/multitile/chimera/relaymove(mob/user, direction)
	if(state == STATE_TUGGED)
		return ..()

	if(last_turn + turn_delay > world.time)
		return FALSE

	if(state != STATE_FLIGHT && state != STATE_VTOL)
		return

	if (dir == turn(direction, 180) || dir == direction)
		return FALSE

	shadow_holder.dir = direction
	try_rotate(turning_angle(dir, direction))

/obj/vehicle/multitile/chimera/try_rotate(deg)
	. = ..()

	if(!.)
		return

	last_turn = world.time
		

/obj/vehicle/multitile/chimera/process(deltatime)
	if (state == STATE_FLIGHT)
		overlays -= thrust_overlay
		pre_movement(dir)
		thrust_overlay = image(icon, "flight_thrust")
		overlays += thrust_overlay

	if(world.time > last_flight_sound + flight_sound_cooldown)
		last_flight_sound = world.time
		playsound(loc, 'sound/vehicles/vtol/exteriorflight.ogg', 25, FALSE)

/obj/vehicle/multitile/chimera/before_move(direction)
	if(state != STATE_FLIGHT && state != STATE_VTOL)
		return
	
	var/turf/below = SSmapping.get_turf_below(get_turf(src))

	if(!below)	
		return

	shadow_holder.dir = direction
	shadow_holder.forceMove(below)

/obj/vehicle/multitile/chimera/add_seated_verbs(mob/living/M, seat)
	if(!M.client)
		return
	add_verb(M.client, list(
		/obj/vehicle/multitile/proc/get_status_info,
		/obj/vehicle/multitile/proc/toggle_door_lock,
		/obj/vehicle/multitile/proc/activate_horn,
		/obj/vehicle/multitile/proc/name_vehicle,
		/obj/vehicle/multitile/chimera/proc/takeoff,
		/obj/vehicle/multitile/chimera/proc/land,
		/obj/vehicle/multitile/chimera/proc/toggle_vtol,
		/obj/vehicle/multitile/chimera/proc/toggle_stow
	))

	give_action(M, /datum/action/human_action/chimera/takeoff)
	give_action(M, /datum/action/human_action/chimera/land)
	give_action(M, /datum/action/human_action/chimera/toggle_vtol)
	give_action(M, /datum/action/human_action/chimera/toggle_stow)
	give_action(M, /datum/action/human_action/chimera/disconnect_tug)


/obj/vehicle/multitile/chimera/remove_seated_verbs(mob/living/M, seat)
	if(!M.client)
		return
	remove_verb(M.client, list(
		/obj/vehicle/multitile/proc/get_status_info,
		/obj/vehicle/multitile/proc/toggle_door_lock,
		/obj/vehicle/multitile/proc/activate_horn,
		/obj/vehicle/multitile/proc/name_vehicle,
		/obj/vehicle/multitile/chimera/proc/takeoff,
		/obj/vehicle/multitile/chimera/proc/land,
		/obj/vehicle/multitile/chimera/proc/toggle_vtol,
		/obj/vehicle/multitile/chimera/proc/toggle_stow
	))

	remove_action(M, /datum/action/human_action/chimera/takeoff)
	remove_action(M, /datum/action/human_action/chimera/land)
	remove_action(M, /datum/action/human_action/chimera/toggle_vtol)
	remove_action(M, /datum/action/human_action/chimera/toggle_stow)
	remove_action(M, /datum/action/human_action/chimera/disconnect_tug)

	SStgui.close_user_uis(M, src)	

/obj/vehicle/multitile/chimera/give_seated_mob_actions(mob/seated_mob)
	give_action(seated_mob, /datum/action/human_action/vehicle_unbuckle/chimera)

/obj/vehicle/multitile/chimera/Collided(atom/movable/collided_atom)
	if(!istype(collided_atom, /obj/structure/chimera_tug))
		return
	
	if(collided_atom.dir != REVERSE_DIR(dir))
		return

	qdel(collided_atom)
	state = STATE_TUGGED
	move_delay = VEHICLE_SPEED_NORMAL
	update_icon()

/obj/vehicle/multitile/chimera/proc/disconnect_tug()
	state = STATE_STOWED
	update_icon()

	var/turf/disconnect_turf

	switch(dir)
		if(SOUTH)
			disconnect_turf = locate(x, y - 2, z)
		if(NORTH)
			disconnect_turf = locate(x, y + 2, z)
		if(EAST)
			disconnect_turf = locate(x + 2, y, z)
		if(WEST)
			disconnect_turf = locate(x - 2, y, z)

	var/obj/structure/chimera_tug/tug = new(disconnect_turf)
	tug.dir = dir

/obj/vehicle/multitile/chimera/proc/start_takeoff()
	if(!is_ground_level(z))
		return
	
	if(busy)
		return

	busy = TRUE

	playsound(loc, 'sound/vehicles/vtol/takeoff.ogg', 25, FALSE)
	addtimer(CALLBACK(src, PROC_REF(takeoff_engage_vtol)), 20 SECONDS)

/obj/vehicle/multitile/chimera/proc/takeoff_engage_vtol()
	state = STATE_TAKEOFF_LANDING
	update_icon()
	playsound(loc, 'sound/vehicles/vtol/mechanical.ogg', 25, FALSE)
	addtimer(CALLBACK(src, PROC_REF(finish_takeoff)), 10 SECONDS)

/obj/vehicle/multitile/chimera/proc/finish_takeoff()
	flags_atom |= NO_ZFALL
	state = STATE_VTOL
	update_icon()
	forceMove(SSmapping.get_turf_above(get_turf(src)))
	shadow_holder.forceMove(SSmapping.get_turf_below(src))
	START_PROCESSING(SSsuperfastobj, src)
	busy = FALSE

/obj/vehicle/multitile/chimera/proc/start_landing()
	if(!is_ground_level(z))
		return
	
	if(busy)
		return

	busy = TRUE
	state = STATE_TAKEOFF_LANDING
	update_icon()

	playsound(loc, 'sound/vehicles/vtol/landing.ogg', 25, FALSE)
	addtimer(CALLBACK(src, PROC_REF(finish_landing)), 18 SECONDS)

/obj/vehicle/multitile/chimera/proc/finish_landing()
	forceMove(SSmapping.get_turf_below(get_turf(src)))
	shadow_holder.forceMove(src)
	flags_atom &= ~NO_ZFALL
	state = STATE_STOWED
	update_icon()
	STOP_PROCESSING(SSsuperfastobj, src)
	busy = FALSE

/obj/vehicle/multitile/chimera/proc/toggle_stowed()
	if(busy)
		return

	busy = TRUE
	playsound(loc, 'sound/vehicles/vtol/mechanical.ogg', 25, FALSE)
	addtimer(CALLBACK(src, PROC_REF(transition_stowed)), 4 SECONDS)

/obj/vehicle/multitile/chimera/proc/transition_stowed()
	if(state == STATE_DEPLOYED)
		state = STATE_STOWED
	else
		state = STATE_DEPLOYED

	update_icon()
	busy = FALSE

/obj/vehicle/multitile/chimera/proc/takeoff()
	set name = "Takeoff"
	set desc = "Initiate the take off sequence."
	set category = "Vehicle"

	var/mob/user = usr
	if(!istype(user))
		return

	var/obj/vehicle/multitile/chimera/vehicle = user.interactee
	if(!istype(vehicle))
		return

	var/seat
	for(var/vehicle_seat in vehicle.seats)
		if(vehicle.seats[vehicle_seat] == user)
			seat = vehicle_seat
			break

	if(!seat)
		return

	if(vehicle.state != STATE_DEPLOYED)
		return

	vehicle.start_takeoff()
	return

/obj/vehicle/multitile/chimera/proc/toggle_vtol()
	set name = "Toggle VTOL"
	set desc = "Toggle VTOL mode."
	set category = "Vehicle"

	var/mob/user = usr
	if(!istype(user))
		return

	var/obj/vehicle/multitile/chimera/vehicle = user.interactee
	if(!istype(vehicle))
		return

	var/seat
	for(var/vehicle_seat in vehicle.seats)
		if(vehicle.seats[vehicle_seat] == user)
			seat = vehicle_seat
			break

	if(!seat)
		return

	if(!is_ground_level(vehicle.z))
		return

	if(vehicle.state != STATE_FLIGHT && vehicle.state != STATE_VTOL)
		return

	if(vehicle.state == STATE_FLIGHT)
		vehicle.state = STATE_VTOL
		vehicle.update_icon()
	else if (vehicle.state == STATE_VTOL)
		vehicle.state = STATE_FLIGHT
		vehicle.update_icon()

/obj/vehicle/multitile/chimera/proc/land()
	set name = "Land"
	set desc = "Initiate the landing sequence."
	set category = "Vehicle"

	var/mob/user = usr
	if(!istype(user))
		return

	var/obj/vehicle/multitile/chimera/vehicle = user.interactee
	if(!istype(vehicle))
		return

	var/seat
	for(var/vehicle_seat in vehicle.seats)
		if(vehicle.seats[vehicle_seat] == user)
			seat = vehicle_seat
			break

	if(!seat)
		return

	if(vehicle.state == STATE_STOWED || vehicle.state == STATE_TAKEOFF_LANDING)
		return

	vehicle.start_landing()

/obj/vehicle/multitile/chimera/proc/toggle_stow()
	set name = "Toggle Stow Mode"
	set desc = "Toggle between stowed and deployed mode."
	set category = "Vehicle"

	var/mob/user = usr
	if(!istype(user))
		return

	var/obj/vehicle/multitile/chimera/vehicle = user.interactee
	if(!istype(vehicle))
		return

	var/seat
	for(var/vehicle_seat in vehicle.seats)
		if(vehicle.seats[vehicle_seat] == user)
			seat = vehicle_seat
			break

	if(!seat)
		return

	if(vehicle.state != STATE_DEPLOYED && vehicle.state != STATE_STOWED)
		return

	vehicle.toggle_stowed()
	return


/datum/action/human_action/chimera/New(Target, obj/item/holder)
	. = ..()
	button.name = name
	button.overlays.Cut()
	button.overlays += image('icons/mob/hud/actions.dmi', button, action_icon_state)

/datum/action/human_action/chimera/action_activate()
	playsound(owner.loc, 'sound/vehicles/vtol/buttonpress.ogg', 25, FALSE)

/datum/action/human_action/chimera/takeoff
	name = "Takeoff"
	action_icon_state = "takeoff"

/datum/action/human_action/chimera/takeoff/action_activate()
	var/obj/vehicle/multitile/chimera/vehicle = owner.interactee
	
	if(!istype(vehicle))
		return

	. = ..()

	vehicle.takeoff()

/datum/action/human_action/chimera/land
	name = "Land"
	action_icon_state = "land"

/datum/action/human_action/chimera/land/action_activate()
	var/obj/vehicle/multitile/chimera/vehicle = owner.interactee
	
	if(!istype(vehicle))
		return

	. = ..()

	vehicle.land()

/datum/action/human_action/chimera/toggle_vtol
	name = "Toggle VTOL"
	action_icon_state = "vtol-mode-transition"

/datum/action/human_action/chimera/toggle_vtol/action_activate()
	var/obj/vehicle/multitile/chimera/vehicle = owner.interactee
	
	if(!istype(vehicle))
		return

	. = ..()

	vehicle.toggle_vtol()

/datum/action/human_action/chimera/toggle_stow
	name = "Toggle Stow Mode"
	action_icon_state = "stow-mode-transition"

/datum/action/human_action/chimera/toggle_stow/action_activate()
	var/obj/vehicle/multitile/chimera/vehicle = owner.interactee
	
	if(!istype(vehicle))
		return

	. = ..()

	vehicle.toggle_stow()

/datum/action/human_action/chimera/disconnect_tug
	name = "Disconnect Tug"
	action_icon_state = "tug-disconnect"

/datum/action/human_action/chimera/disconnect_tug/action_activate()
	var/obj/vehicle/multitile/chimera/vehicle = owner.interactee
	
	if(!istype(vehicle))
		return

	. = ..()

	vehicle.disconnect_tug()

/datum/action/human_action/vehicle_unbuckle/chimera
	action_icon_state = "pilot-unbuckle"

/obj/structure/chimera_tug
	name = "aerospace tug"
	desc = ""
	icon = 'icons/obj/vehicles/chimera_tug.dmi'
	icon_state = "aerospace-tug"
	density = TRUE
	anchored = FALSE

	pixel_x = -16
	pixel_y = 0

/obj/structure/landing_pad_folded
	name = "folded landing pad"
	desc = ""
	icon = 'icons/obj/vehicles/chimera_structures.dmi'
	icon_state = "landing-pad-folded"
	density = TRUE
	anchored = FALSE

	pixel_x = -16
	pixel_y = -16

/obj/structure/landing_pad_folded/attackby(obj/item/hit_item, mob/user)
	if(!HAS_TRAIT(hit_item, TRAIT_TOOL_WRENCH))
		return

	if(!is_ground_level(user.z))
		to_chat(user, SPAN_WARNING("You probably shouldn't deploy this here."))
		return

	for(var/atom/possible_blocker in CORNER_BLOCK(loc, 3, 3))
		if(possible_blocker.density)
			to_chat(user, SPAN_WARNING("There is something in the way, you need a more open area."))
			return FALSE

	playsound(loc, 'sound/items/Ratchet.ogg', 25, 1)

	to_chat(user, SPAN_NOTICE("You start assembling the landing pad..."))

	if(!do_after(user, 20 SECONDS, INTERRUPT_ALL, BUSY_ICON_BUILD))
		return

	for(var/atom/possible_blocker in CORNER_BLOCK(loc, 3, 3))
		if(possible_blocker.density)
			to_chat(user, SPAN_WARNING("There is something in the way, you need a more open area."))
			return FALSE

	to_chat(user, SPAN_NOTICE("You assemble the landing pad."))
		
	new /obj/structure/landing_pad(loc)

	qdel(src)

/obj/item/landing_pad_light
	name = "landing pad light"
	icon = 'icons/obj/vehicles/chimera_peripherals.dmi'
	icon_state = "landing pad light"
	layer = BELOW_MOB_LAYER

/obj/item/flight_cpu
	name = "flight cpu crate"
	icon = 'icons/obj/vehicles/chimera_peripherals.dmi'
	icon_state = "flightcpu-crate"
	layer = BELOW_MOB_LAYER

	var/obj/structure/landing_pad/linked_pad
	var/fueling = FALSE

/obj/item/flight_cpu/Initialize(mapload, obj/structure/landing_pad/linked_pad = null)
	src.linked_pad = linked_pad

	. = ..()

/obj/item/flight_cpu/Destroy()
	linked_pad = null
	
	. = ..()

/obj/item/flight_cpu/attack_hand(mob/user)
	if(!linked_pad)
		return ..()

	playsound(loc, 'sound/vehicles/vtol/buttonpress.ogg', 25, FALSE)

	if(!linked_pad.fuelpump_installed)
		to_chat(user, SPAN_WARNING("ERROR: Fuel pump not detected."))
		return

	if(linked_pad.installed_lights < 4)
		to_chat(user, SPAN_WARNING("ERROR: Insufficent landing lights detected for safe operation."))
		return

	tgui_interact(user)

/obj/item/flight_cpu/tgui_interact(mob/user, datum/tgui/ui)
	. = ..()

	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "FlightComputer", "Flight Computer", 900, 600)
		ui.open()

/obj/item/flight_cpu/ui_data(mob/user)
	var/list/data = list()

	var/turf/center_turf = locate(x + 1, y + 1, z)


	for(var/obj/vehicle/multitile/chimera/aircraft in center_turf.contents)
		if(aircraft.x == center_turf.x + 1 && aircraft.y == aircraft.y)
			data["vtol_detected"] = TRUE
			data["fuel"] = aircraft.fuel
			data["max_fuel"] = aircraft.max_fuel
			data["fueling"] = fueling

	return data

/obj/item/flight_cpu/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()

	var/turf/center_turf = locate(x + 1, y + 1, z)
	var/obj/vehicle/multitile/chimera/parked_aircraft

	for(var/obj/vehicle/multitile/chimera/aircraft in center_turf.contents)
		if(aircraft.x == center_turf.x + 1 && aircraft.y == aircraft.y)
			parked_aircraft = aircraft
			break

	if(!parked_aircraft)
		return

	switch (action)
		if("start_fueling")
			fueling = TRUE
			START_PROCESSING(SSobj, src)
		if("stop_fueling")
			fueling = FALSE
			STOP_PROCESSING(SSobj, src)

/obj/item/flight_cpu/process(deltatime)
	var/turf/center_turf = locate(x + 1, y + 1, z)
	var/obj/vehicle/multitile/chimera/parked_aircraft

	for(var/obj/vehicle/multitile/chimera/aircraft in center_turf.contents)
		if(aircraft.x == center_turf.x + 1 && aircraft.y == aircraft.y)
			parked_aircraft = aircraft
			break

	if(!parked_aircraft)
		STOP_PROCESSING(SSobj, src)
		fueling = FALSE
		return

	if(parked_aircraft.fuel < parked_aircraft.max_fuel)
		parked_aircraft.fuel = min(parked_aircraft.fuel + 2 * deltatime, parked_aircraft.max_fuel)
	else
		STOP_PROCESSING(SSobj, src)
		fueling = FALSE

/obj/item/fuel_pump
	name = "fuelpump crate"
	icon = 'icons/obj/vehicles/chimera_peripherals.dmi'
	icon_state = "fuelpump-crate"
	layer = BELOW_MOB_LAYER

/obj/structure/landing_pad
	name = "landing pad"
	desc = ""
	icon = 'icons/obj/vehicles/chimera_landing_pad.dmi'
	icon_state = "pad"
	light_pixel_x = 48
	light_pixel_y = 48

	pixel_x = -2
	pixel_y = 4

	var/installed_lights = 0
	var/flight_cpu_installed = FALSE
	var/fuelpump_installed = FALSE

/obj/structure/landing_pad/attackby(obj/item/hit_item, mob/user)
	if(istype(hit_item, /obj/item/landing_pad_light))
		if(installed_lights >= 4)
			return
		
		qdel(hit_item)
		hit_item = new /obj/item/landing_pad_light(src)
		vis_contents += hit_item
		hit_item.icon_state = "landing pad light on"
		installed_lights++
		set_light(installed_lights, 3, LIGHT_COLOR_RED)
		switch(installed_lights)
			if(1)
				hit_item.pixel_x = -2
				hit_item.pixel_y = 1
			if(2)
				hit_item.pixel_x = 71
				hit_item.pixel_y = 1
			if(3)
				hit_item.pixel_x = -2
				hit_item.pixel_y = 91
			if(4)
				hit_item.pixel_x = 71
				hit_item.pixel_y = 91
		return

	if(istype(hit_item, /obj/item/flight_cpu))
		if(flight_cpu_installed)
			return

		if(!do_after(user, 2 SECONDS, INTERRUPT_ALL, BUSY_ICON_BUILD))
			return
		
		qdel(hit_item)
		hit_item = new /obj/item/flight_cpu(locate(x - 1, y, z), src)
		hit_item.name = "flight cpu"
		hit_item.pixel_x = -7
		hit_item.pixel_y = -2
		hit_item.icon = 'icons/obj/vehicles/chimera_structures.dmi'
		hit_item.icon_state = "flight-cpu"
		flight_cpu_installed = TRUE
		return

	if(istype(hit_item, /obj/item/fuel_pump))
		if(fuelpump_installed)
			return

		if(!do_after(user, 2 SECONDS, INTERRUPT_ALL, BUSY_ICON_BUILD))
			return
		
		qdel(hit_item)
		hit_item = new /obj/item/fuel_pump(src)
		vis_contents += hit_item
		hit_item.name = "fuel pump"
		hit_item.pixel_x = -25
		hit_item.pixel_y = 29
		hit_item.icon = 'icons/obj/vehicles/chimera_structures.dmi'
		hit_item.icon_state = "fuel pump"
		fuelpump_installed = TRUE
		return



#undef STATE_TUGGED
#undef STATE_STOWED
#undef STATE_DEPLOYED
#undef STATE_TAKEOFF_LANDING
#undef STATE_VTOL
#undef STATE_FLIGHT
