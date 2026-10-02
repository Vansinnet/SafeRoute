return {
    mod_name = {
        en = "SafeRoute",
        sv = "SafeRoute",
    },
    mod_description = {
        en = "Marks the safe road at every branching path (Spillway): SAFE ROUTE and WRONG WAY markers on the roads, and guide dots from each fork to them.",
        sv = "Markerar den säkra vägen vid varje förgrening (Spillway): SÄKER VÄG- och FEL VÄG-markörer på vägarna, och vägledande prickar från varje förgrening fram till dem.",
    },
    show_wrong_roads = {
        en = "Mark wrong roads",
        sv = "Markera fel vägar",
    },
    show_wrong_roads_tooltip = {
        en = "Shows a red marker a few metres into every road the mission did not choose.",
        sv = "Visar en röd markör en bit in i varje väg som uppdraget inte valde.",
    },
    show_guide_dots = {
        en = "Guide dots from the fork",
        sv = "Vägledande prickar från förgreningen",
    },
    show_guide_dots_tooltip = {
        en = "Dots along the walkable path (also up stairs) from each fork: green to the SAFE ROUTE marker, red to each WRONG WAY marker (red only with Mark wrong roads). The dots hide behind walls.",
        sv = "Prickar längs gångvägen (även uppför trappor) från varje förgrening: gröna till SÄKER VÄG-markören, röda till varje FEL VÄG-markör (röda bara med Markera fel vägar). Prickarna döljs bakom väggar.",
    },
    max_distance = {
        en = "Marker range (m)",
        sv = "Markörernas räckvidd (m)",
    },
    max_distance_tooltip = {
        en = "Markers and dots are shown when you are closer than this. SAFE ROUTE and WRONG WAY markers show through walls.",
        sv = "Markörer och prickar visas när du är närmare än så här. SÄKER VÄG- och FEL VÄG-markörerna syns genom väggar.",
    },
    announce = {
        en = "Announce in chat",
        sv = "Meddela i chatten",
    },
    announce_tooltip = {
        en = "Writes a chat line when a mission with branching paths loads.",
        sv = "Skriver en rad i chatten när ett uppdrag med förgreningar laddas.",
    },
    label_safe = {
        en = "SAFE ROUTE",
        sv = "SÄKER VÄG",
    },
    label_wrong = {
        en = "WRONG WAY",
        sv = "FEL VÄG",
    },
    announce_text = {
        en = "SafeRoute: %d branching paths found, safe roads marked.",
        sv = "SafeRoute: %d förgreningar hittade, säkra vägar markerade.",
    },
    crossroad_line = {
        en = "Branching %d: safe road %s of %d",
        sv = "Förgrening %d: säker väg %s av %d",
    },
    guide_found = {
        en = "  Fork found (%d path nodes lead in, %.1f m from the road start)",
        sv = "  Förgrening hittad (%d vägnoder leder dit, %.1f m från vägens början)",
    },
    guide_missing = {
        en = "  Fork not found: guide dots start at each road's first node",
        sv = "  Förgrening hittades inte: prickarna börjar vid varje vägs första nod",
    },
    no_crossroads = {
        en = "SafeRoute: this mission has no branching paths.",
        sv = "SafeRoute: det här uppdraget har inga förgreningar.",
    },
    command_description = {
        en = "List the branching paths of this mission and their safe road.",
        sv = "Lista uppdragets förgreningar och deras säkra väg.",
    },
}
