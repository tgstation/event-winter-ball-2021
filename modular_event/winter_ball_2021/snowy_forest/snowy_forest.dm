/turf/open/floor/stonebrick
	name = "stone brick path"
	icon = 'modular_event/winter_ball_2021/snowy_forest/stonebrick.dmi'
	icon_state = "stonebrick"
	base_icon_state = "stonebrick"

/obj/structure/fluff/christmas_lamp
	name = "decorative lamp post"
	desc = "A lamp post decorated with a festive reef."
	icon = 'modular_event/winter_ball_2021/snowy_forest/2x2.dmi'
	icon_state = "lightpost"
	anchored = TRUE
	deconstructible = FALSE

/obj/effect/decal/turf_decal/shadow
	icon = 'modular_event/winter_ball_2021/snowy_forest/shadow.dmi'
	icon_state = "shadow_decal"

/obj/effect/decal/turf_decal/shadow/corner
	icon_state = "shadow_decal_corner"

/obj/structure/sign/departments/hotspring
	name = "\improper Hotspring sign"
	icon = 'modular_event/winter_ball_2021/snowy_forest/onsen.dmi'
	icon_state = "onsen"
	sign_change_name = "Hotspring"
	desc = "A sign signifying a medicinal hotspring. It has the operating hours carved into it."

/obj/structure/sign/departments/hotspring/shower
	name = "\improper Shower sign"
	icon_state = "showers"
	sign_change_name = "Showers"
	desc = "A sign designating the showering area. It says you should wash up before entering the spring."

/obj/structure/sign/departments/hotspring/sauna
	name = "\improper Sauna sign"
	icon_state = "sauna"
	sign_change_name = "Sauna"
	desc = "A sign designating the sauna. It says tattoos are prohibited."

/obj/structure/curtain/hotspring
	icon = 'modular_event/winter_ball_2021/snowy_forest/onsen.dmi'
	color = null
	alpha = 255
	opaque_closed = TRUE

/obj/structure/curtain/hotspring/men
	name = "Men's Bath"
	icon_type = "m_bath"
	icon_state = "m_bath-open"

/obj/structure/curtain/hotspring/women
	name = "Women's Bath"
	icon_type = "w_bath"
	icon_state = "w_bath-open"
