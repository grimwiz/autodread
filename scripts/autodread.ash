script "autodread.ash";
since r29000;

// autodread: spends turns in your clan's Dreadsylvania the way a good clanmate would.
//   1. Ghost pencil: once an instance, take the schoolhouse pencil (buying a skeleton key with Freddy Kruegerands
//      if the schoolhouse is still locked) and use it to record a place on your map you haven't recorded.
//   2. Your noncombats: each player gets one action per noncombat per instance. Recorded places are reached
//      straight away by map shortcut (1 turn); the action taken is the Freddy Kruegerand or rare-item option.
//      It never takes an option that banishes an element or a monster type (that makes the zone harder for
//      everyone) and never fights a boss.
//   3. Fights, with spells only, in the zone furthest from done, keeping the clan rule: don't take a zone to
//      100% until the other two are near completion (a ready boss shuts that zone's noncombats for everyone).
//   4. The carriageman: if the Village or Castle is still shut, feed him drinks to open it.
//
// Usage (KoLmafia command line):
//   autodread          spend all adventures (or until there's nothing useful left)
//   autodread N        spend at most N turns
//   autodread pencil   open the Village and Castle if they're shut, collect this instance's ghost pencil, then stop
//                      (autosea calls this on the way to Dad Sea Monkee). The pencil is used by a later run, when it
//                      meets a place that isn't on your map.
//   autodread map      the same, then record a place on your map with the pencil: fights where one can turn up
//                      until it does (that can take a hundred turns or more), then stop
//   autodread status   show the instance, your noncombats and your map, without adventuring

// ---------------------------------------------------------------- logging and settings
// Settings are ordinary KoLmafia properties, changed with "set autodread_<name> = <value>".

void ad_info(string msg)
{
	print("[autodread] " + msg, "blue");
}

void ad_warn(string msg)
{
	print("[autodread] " + msg, "red");
}

void ad_debug(string msg)
{
	if(get_property("autodread_debug").to_boolean())
	{
		print("[autodread debug] " + msg, "gray");
	}
}

string ad_setting(string name, string fallback)
{
	string value = get_property("autodread_" + name);
	return value == "" ? fallback : value;
}

string[string] ad_savedPrefs;

void ad_overrideProperty(string prop, string value)
{
	if(!(ad_savedPrefs contains prop))
	{
		ad_savedPrefs[prop] = get_property(prop);
	}
	set_property(prop, value);
}

void ad_restoreProperties()
{
	foreach prop, value in ad_savedPrefs
	{
		set_property(prop, value);
	}
	clear(ad_savedPrefs);
}

// ---------------------------------------------------------------- the places
// The nine noncombats (three per zone). shortcut: the map shortcut number, also ghostPencilN and
// clan_dreadsylvania.php?action=forceloc&loc=N. done: raid-log phrases for every action there, any one of which
// means you've had your action this instance.

record ad_place
{
	int shortcut;
	int choice;
	string name;
	string zone;	//Woods, Village or Castle
	string done;
};

ad_place[int] ad_places()
{
	ad_place[int] p;
	p[1] = new ad_place(1, 721, "The Cabin", "Woods", "dread tarragon|bone flour|forest less stinky|recycled some newspapers|read an old diary|auditor's badge|impression of a complicated lock|forest less spooky|drove some werewolves|drove some vampires|photo album");
	p[2] = new ad_place(2, 725, "The Tallest Tree", "Woods", "fruit loose|forest less sleazy|moon-amber|drove some ghosts|footlocker|lifted some weights|blood kiwi|wasted some fruit|seed pod");
	p[3] = new ad_place(3, 729, "The Burrows", "Woods", "forest less hot|hot coals|cool iron ingot|forest less cold|forest's heart|forest goo|drove some bugbears|baseball card");
	p[4] = new ad_place(4, 733, "The Village Square", "Village", "drove some ghosts|ghost pencil|naughty carvings|village less cold|blacksmith's till|iron helmet|iron greaves|iron breastplate|village less spooky|hung");
	p[5] = new ad_place(5, 737, "Skid Row", "Village", "village less stinky|swam in a sewer|drove some skeletons|village less sleazy|bricks|tinker's shack|complicated key|polished some moon-amber|clockwork bird|old fuse");
	p[6] = new ad_place(6, 741, "The Old Duke's Estate", "Village", "drove some zombies|robbed some graves|lurid epitaphs|village less hot|shepherd's pie|naughty cabinets|drove some werewolves|eau de mort|ghost shawl");
	p[7] = new ad_place(7, 745, "The Great Hall", "Castle", "drove some vampires|dance floor|castle less cold|freezer|roast beast|castle less stinky|wax banana");
	p[8] = new ad_place(8, 749, "The Tower", "Castle", "drove some bugbears|drove some zombies|The Machine|kiwitini|drove some skeletons|ancient secrets|moon-amber necklace|castle less sleazy|raided a dresser|magically fingered");
	p[9] = new ad_place(9, 753, "The Dungeons", "Castle", "castle less spooky|pushups|prison cot|castle less hot|sifted through some ashes|relaxed in a furnace|stinking agaric");
	return p;
}

location ad_zoneLocation(string zone)
{
	switch(zone)
	{
		case "Woods": return $location[Dreadsylvanian Woods];
		case "Village": return $location[Dreadsylvanian Village];
		case "Castle": return $location[Dreadsylvanian Castle];
	}
	return $location[none];
}

// ---------------------------------------------------------------- reading the instance
// The clan raid log holds everything: kills per zone (1,000 each, then the boss), and a line per player per action,
// grouped by zone, e.g. "grimwiz (#123) recycled some newspapers (1 turn)".

string ad_log;
int[string] ad_kills;
string[string] ad_section;	//zone -> that zone's raid-log lines

boolean ad_readLog()
{
	ad_log = visit_url("clan_raidlogs.php");
	clear(ad_kills);
	clear(ad_section);
	int start = ad_log.index_of("<div id='Dreadsylvania'>");
	if(start < 0)
	{
		return false;
	}
	ad_log = ad_log.substring(start);
	matcher m = create_matcher("Your clan has defeated <b>([\\d,]+)</b> monster\\(s\\) in the (Forest|Village|Castle)", ad_log);
	while(m.find())
	{
		ad_kills[m.group(2) == "Forest" ? "Woods" : m.group(2)] = m.group(1).to_int();
	}
	m = create_matcher("<b>The (Woods|Forest|Village|Castle)</b><blockquote>(.*?)</blockquote>", ad_log);
	while(m.find())
	{
		ad_section[m.group(1) == "Forest" ? "Woods" : m.group(1)] = m.group(2);
	}
	return true;
}

int ad_kisses()
{
	matcher m = create_matcher("<b>([\\d,]+)</b> kisses earned", ad_log);
	return m.find() ? m.group(1).to_int() : 0;
}

boolean ad_bossReady(string zone)
{
	return ad_kills[zone] >= 1000;
}

// how many times anyone has done something in a zone (Freddy options and pencils are limited to 10 a clan)
int ad_countInZone(string zone, string phrase)
{
	int n = 0;
	matcher m = create_matcher(phrase, ad_section[zone]);
	while(m.find())
	{
		n += 1;
	}
	return n;
}

// your own lines in a zone
string ad_myLines(string zone)
{
	string mine = "";
	foreach i, line in ad_section[zone].split_string("<br>")
	{
		if(line.contains_text("(#" + my_id() + ")"))
		{
			mine += line + "\n";
		}
	}
	return mine;
}

boolean ad_placeUsed(ad_place p)
{
	return create_matcher(p.done, ad_myLines(p.zone)).find();
}

// The carriageman takes the clan to the Village at 1,000 "sheets" and the Castle at 2,000.
int ad_carriageSheets()
{
	matcher m = create_matcher("currently ([\\d,]+) sheets? to the wind", visit_url("clan_dreadsylvania.php?place=carriage"));
	if(m.find())
	{
		return m.group(1).to_int();
	}
	int sheets = 0;	//fall back on the raid log
	m = create_matcher("got the carriageman ([\\d,]+) sheet\\(s\\) drunker", ad_log);
	while(m.find())
	{
		sheets += m.group(1).to_int();
	}
	return sheets;
}

int ad_carriageNeed(string zone)
{
	return zone == "Village" ? 1000 : zone == "Castle" ? 2000 : 0;
}

boolean ad_zoneReachable(string zone, int sheets)
{
	return sheets >= ad_carriageNeed(zone);
}

// clan rule: don't take a zone to 100% until the other two are near completion
boolean ad_mayFight(string zone)
{
	if(ad_bossReady(zone))
	{
		return false;
	}
	int stopAt = ad_setting("stopAt", "950").to_int();
	if(ad_kills[zone] < stopAt)
	{
		return true;
	}
	int othersAt = ad_setting("othersAt", "900").to_int();
	foreach other in $strings[Woods, Village, Castle]
	{
		if(other != zone && ad_kills[other] < othersAt)
		{
			return false;
		}
	}
	return true;
}

// ---------------------------------------------------------------- what to do at each place
// Your usual choices: the Freddy Kruegerand option at most places, the wax banana (or roast) in the Great Hall,
// the ghost pencil in the Village Square. With a ghost pencil and an unrecorded place, option 5 records it
// (it costs the pencil and a turn but not your action). Option 6 leaves without spending a turn.

int ad_pencils()
{
	return item_amount($item[ghost pencil]);
}

boolean ad_recorded(ad_place p)
{
	return get_property("ghostPencil" + p.shortcut).to_boolean();
}

boolean ad_anyUnrecorded()
{
	foreach i, p in ad_places()
	{
		if(!ad_recorded(p))
		{
			return true;
		}
	}
	return false;
}

// the pencil is taken in the Village Square: once a player per instance, ten a clan
boolean ad_pencilWanted()
{
	ad_place square = ad_places()[4];
	return ad_pencils() == 0 && ad_anyUnrecorded() && !ad_placeUsed(square) && !ad_bossReady("Village")
		&& ad_countInZone("Village", "collected a ghost pencil") < 10;
}

boolean ad_schoolUnlocked()
{
	return ad_section["Village"].contains_text("unlocked the schoolhouse");
}

// top option, sub-choice and sub option for a place; top 6 = leave (no turn)
record ad_plan
{
	int top;
	int sub;
	int subOption;
	string what;
};

int ad_owned(item it)
{
	return item_amount(it) + closet_amount(it) + storage_amount(it) + display_amount(it) + equipped_amount(it);
}

ad_plan ad_planFor(ad_place p)
{
	if(ad_pencils() > 0 && !ad_recorded(p))
	{
		return new ad_plan(5, 0, 0, "record " + p.name + " with the ghost pencil");
	}
	if(ad_placeUsed(p) || ad_bossReady(p.zone))
	{
		return new ad_plan(6, 0, 0, "");
	}
	switch(p.choice)
	{
		case 721:
			if(ad_countInZone("Woods", "recycled some newspapers") < 10)
				return new ad_plan(2, 723, 1, "Freddies from the newspapers");
			break;
		case 725:
			//the fire tower needs a skeleton key (once a clan); the footlocker is up there
			if(ad_section["Woods"].contains_text("unlocked the fire watchtower") && ad_countInZone("Woods", "rifled through a footlocker") < 10)
				return new ad_plan(2, 727, 2, "Freddies from the footlocker");
			break;
		case 729:
			if(ad_countInZone("Woods", "baseball card") < 10)
				return new ad_plan(3, 732, 2, "Freddies from the garbage");
			break;
		case 733:
			if(ad_pencilWanted() && ad_schoolUnlocked())
				return new ad_plan(1, 734, 2, "the ghost pencil");
			if(ad_countInZone("Village", "blacksmith's till") < 10)
				return new ad_plan(2, 735, 2, "Freddies from the blacksmith's till");
			break;
		case 741:
			if(ad_countInZone("Village", "robbed some graves") < 10)
				return new ad_plan(1, 742, 2, "Freddies from the graves");
			break;
		case 745:
			//one banana makes the one lock impression you need; the replica key also needs a Moxie class and music box parts
			if(!ad_section["Castle"].contains_text("got a wax banana") && ad_owned($item[wax banana]) + ad_owned($item[complicated lock impression]) + ad_owned($item[replica key]) == 0)
				return new ad_plan(3, 748, 3, "the wax banana");
			if(!ad_section["Castle"].contains_text("roast beast"))
				return new ad_plan(3, 748, 1, "the roast");
			break;
		case 749:
			if(ad_countInZone("Castle", "raided a dresser") < 10)
				return new ad_plan(3, 752, 2, "Freddies from the dresser");
			break;
		case 753:
			if(ad_countInZone("Castle", "sifted through some ashes") < 10)
				return new ad_plan(2, 755, 2, "Freddies from the ashes");
			break;
	}
	return new ad_plan(6, 0, 0, "");	//Skid Row's loot is for Moxie classes; the rest only banishes or buffs
}

// set every place's choices for the next adventure, so a noncombat met while fighting does the right thing too
void ad_setPlaceChoices()
{
	foreach i, p in ad_places()
	{
		ad_plan plan = ad_planFor(p);
		ad_overrideProperty("choiceAdventure" + p.choice, plan.top.to_string());
		if(plan.sub > 0)
		{
			ad_overrideProperty("choiceAdventure" + plan.sub, plan.subOption.to_string());
		}
	}
	//bosses: run away (no turn). Penne Basil and friends fight them.
	foreach n in $ints[758, 759, 760]
	{
		ad_overrideProperty("choiceAdventure" + n, "2");
	}
}

// ---------------------------------------------------------------- staying alive and fighting
// Spells only: every lost Dread fight in your logs was a melee macro (ghosts can't be hurt physically).

boolean ad_safe(location loc)
{
	int worst = 0;
	foreach i, mon in get_monsters(loc)
	{
		if(!mon.boss)
		{
			worst = max(worst, expected_damage(mon));
		}
	}
	if(worst * ad_setting("dangerRounds", "3").to_int() >= my_maxhp() * 0.9)
	{
		ad_warn("Skipping " + loc + ": its monsters can hit for about " + worst + " a round, and you have " + my_maxhp() + " HP.");
		return false;
	}
	return true;
}

skill ad_spell(monster enemy)
{
	boolean ghost = enemy.to_string().contains_text("ghost");
	foreach sk in $skills[Saucegeyser, Saucestorm, Weapon of the Pastalord, Stream of Sauce, Cannelloni Cannon]
	{
		if(ghost && (sk == $skill[Weapon of the Pastalord] || sk == $skill[Cannelloni Cannon]))
		{
			continue;	//physical
		}
		if(have_skill(sk))
		{
			return sk;
		}
	}
	return $skill[none];
}

string ad_spellFilter(int round, monster enemy, string text)
{
	skill sk = ad_spell(enemy);
	if(sk != $skill[none] && my_mp() >= mp_cost(sk))
	{
		return "skill " + sk;
	}
	return "runaway";	//better than melee here
}

boolean ad_recover()
{
	if(my_hp() < my_maxhp() * 0.8)
	{
		restore_hp(my_maxhp());
	}
	skill sk = ad_spell($monster[none]);
	int want = sk == $skill[none] ? 0 : mp_cost(sk) * ad_setting("castsReady", "4").to_int();
	if(my_mp() < want)
	{
		restore_mp(min(my_maxmp(), want));
	}
	return my_hp() >= my_maxhp() * 0.5 && my_mp() >= min(want, my_maxmp()) && have_effect($effect[Beaten Up]) == 0;
}

boolean ad_fight(string zone)
{
	location loc = ad_zoneLocation(zone);
	set_location(loc);
	maximize(ad_setting("maximize", "mainstat, spell damage percent, moxie, 0.5 hp, 3 dr"), false);
	if(!ad_safe(loc))
	{
		return false;
	}
	if(!ad_recover())
	{
		ad_warn("Couldn't recover enough HP and MP to fight safely (HP " + my_hp() + "/" + my_maxhp() + ", MP " + my_mp() + ").");
		return false;
	}
	int turnsBefore = my_turncount();
	boolean ok = adv1(loc, -1, "ad_spellFilter");
	if(have_effect($effect[Beaten Up]) > 0)
	{
		ad_warn("Beaten up in " + loc + ". Stopping.");
		return false;
	}
	if(!ok && my_turncount() == turnsBefore)
	{
		ad_warn("The adventure at " + loc + " didn't happen. KoLmafia's reason is in the CLI just above.");
		return false;
	}
	return true;
}

// a recorded place, by map shortcut (1 adventure); the choices set above do the rest
boolean ad_visit(ad_place p, ad_plan plan)
{
	ad_info(p.name + ": " + plan.what + ".");
	int turnsBefore = my_turncount();
	string page = visit_url("clan_dreadsylvania.php?action=forceloc&loc=" + p.shortcut);
	string shortcutPage = page;		// KoL's reply to the shortcut itself, for the report if it doesn't take
	if(page.contains_text("choice.php") || handling_choice())
	{
		run_choice(-1);
	}
	if(my_turncount() == turnsBefore && !handling_choice())
	{
		ad_warn("The shortcut to " + p.name + " didn't take a turn; stopping so it doesn't repeat.");
		// KoLmafia prints no reason when it doesn't recognise the reply (run 108's ghost pencil), so show what KoL said
		string said = create_matcher("(?is)<(script|style)[^>]*>.*?</\\1>", shortcutPage).replace_all(" ");
		said = create_matcher("\\s+", create_matcher("<[^>]*>", said).replace_all(" ")).replace_all(" ");
		ad_warn("KoL's reply to the shortcut (" + length(shortcutPage) + " characters, saved to data/autodread_shortcut_fail.html): "
			+ (length(said) > 600 ? substring(said, 0, 600) + "..." : said));
		buffer_to_file(shortcutPage.to_buffer(), "autodread_shortcut_fail.html");
		return false;
	}
	return true;
}

// ---------------------------------------------------------------- ghost pencil and key

boolean ad_getKey()
{
	if(item_amount($item[Dreadsylvanian skeleton key]) > 0)
	{
		return true;
	}
	if(item_amount($item[Freddy Kruegerand]) < 25)
	{
		return false;
	}
	ad_info("Buying a Dreadsylvanian skeleton key (25 Freddy Kruegerands) for the schoolhouse.");
	buy($coinmaster[The Terrified Eagle Inn], 1, $item[Dreadsylvanian skeleton key]);
	return item_amount($item[Dreadsylvanian skeleton key]) > 0;
}

// ---------------------------------------------------------------- the carriageman
// Each drink counts its average adventures. Drinks you hold that cost little per sheet go first; then the
// cheapest per sheet of a few cocktails from the mall, within autodread_carriageBudget meat.

float ad_avgAdventures(item it)
{
	matcher m = create_matcher("(\\d+)(?:-(\\d+))?", it.adventures);
	if(!m.find())
	{
		return 0;
	}
	float low = m.group(1).to_float();
	float high = m.group(2) == "" ? low : m.group(2).to_float();
	return (low + high) / 2;
}

boolean ad_feed(item it, int qty)
{
	ad_info("Giving the carriageman " + qty + " " + it + ".");
	string page = visit_url("clan_dreadsylvania.php?action=feedbooze&whichbooze=" + it.to_int() + "&boozequantity=" + qty);
	return page.contains_text("gladly accepts");
}

void ad_carriage(int sheets, string zone)
{
	int need = ad_carriageNeed(zone) - sheets;
	if(need <= 0 || !ad_setting("carriage", "true").to_boolean())
	{
		return;
	}
	float maxPerSheet = ad_setting("carriageMaxPerSheet", "30").to_float();
	foreach it in get_inventory()
	{
		float adv = ad_avgAdventures(it);
		if(need <= 0 || it.inebriety <= 0 || adv <= 0 || !it.tradeable || it.quest || it == $item[Instant Karma])
		{
			continue;
		}
		if(mall_price(it) / adv > maxPerSheet)
		{
			continue;	//too good to pour into the carriageman
		}
		int qty = min(item_amount(it), ceil(need / adv));
		if(ad_feed(it, qty))
		{
			need -= floor(qty * adv);
		}
	}
	int budget = ad_setting("carriageBudget", "50000").to_int();
	item best = $item[none];
	foreach name in $strings[pink pony, slip 'n' slide, sidecar, fuzzbump, roll in the hay]
	{
		item it = name.to_item();
		float adv = ad_avgAdventures(it);
		if(it != $item[none] && adv > 0 && mall_price(it) > 0
			&& (best == $item[none] || mall_price(it) / adv < mall_price(best) / ad_avgAdventures(best)))
		{
			best = it;
		}
	}
	if(need > 0 && best != $item[none] && mall_price(best) / ad_avgAdventures(best) <= maxPerSheet)
	{
		int qty = min(ceil(need / ad_avgAdventures(best)), budget / max(1, mall_price(best)));
		if(qty > 0 && buy(qty, best, ceil(maxPerSheet * ad_avgAdventures(best))) > 0)
		{
			ad_feed(best, min(qty, item_amount(best)));
		}
	}
}

// ---------------------------------------------------------------- status

string ad_pct(string zone)
{
	return ad_bossReady(zone) ? "BOSS" : (ad_kills[zone] / 10) + "%";
}

void ad_status()
{
	if(!ad_readLog())
	{
		ad_warn("Your clan has no Dreadsylvania instance open (nothing in the raid log).");
		return;
	}
	int sheets = ad_carriageSheets();
	ad_info("Kisses: " + ad_kisses() + ". Carriageman: " + sheets + " sheets (Village at 1,000, Castle at 2,000).");
	foreach zone in $strings[Woods, Village, Castle]
	{
		string state = !ad_zoneReachable(zone, sheets) ? "shut (the carriageman isn't drunk enough)"
			: ad_pct(zone) + " (" + ad_kills[zone] + " of 1,000 kills)" + (ad_bossReady(zone) ? ", noncombats closed" : ad_mayFight(zone) ? "" : ", held back by the clan rule");
		ad_info(zone + ": " + state + ".");
	}
	string recorded = "";
	string missing = "";
	foreach i, p in ad_places()
	{
		string used = ad_placeUsed(p) ? "action used" : ad_bossReady(p.zone) ? "closed" : "action free";
		ad_info("  " + p.name + " (" + p.zone + "): " + used + (ad_recorded(p) ? ", shortcut on your map." : ", not on your map."));
		if(!ad_recorded(p))
		{
			missing += (missing == "" ? "" : ", ") + p.name;
		}
	}
	ad_info("Map: " + (missing == "" ? "all nine places recorded." : "not recorded yet: " + missing + "."));
	ad_info("Ghost pencils: you hold " + ad_pencils() + "; the clan has taken " + ad_countInZone("Village", "collected a ghost pencil")
		+ " of 10 this instance; schoolhouse " + (ad_schoolUnlocked() ? "unlocked" : "locked")
		+ "; " + (ad_pencilWanted() ? "yours is still to take." : "nothing to take for you this instance."));
	ad_info("Freddy Kruegerands: " + item_amount($item[Freddy Kruegerand]) + ". Skeleton keys: " + item_amount($item[Dreadsylvanian skeleton key]) + ".");
}

// ---------------------------------------------------------------- the run

// one useful thing; false when there's nothing left (said why)
boolean ad_turn()
{
	if(!ad_readLog())
	{
		ad_warn("Your clan has no Dreadsylvania instance open.");
		return false;
	}
	int sheets = ad_carriageSheets();
	foreach zone in $strings[Village, Castle]
	{
		if(!ad_zoneReachable(zone, sheets))
		{
			ad_carriage(sheets, zone);
			sheets = ad_carriageSheets();
		}
	}
	ad_setPlaceChoices();

	//1. a pencil in hand: go where an unrecorded place can turn up (no shortcut to it, by definition)
	if(ad_pencils() > 0)
	{
		foreach i, p in ad_places()
		{
			if(!ad_recorded(p) && !ad_placeUsed(p) && ad_zoneReachable(p.zone, sheets) && ad_mayFight(p.zone))
			{
				ad_debug("holding a pencil: adventuring in the " + p.zone + " for " + p.name);
				return ad_fight(p.zone);
			}
		}
	}
	//2. take this instance's pencil (the Village Square is on your map)
	if(ad_pencilWanted() && ad_zoneReachable("Village", sheets))
	{
		if(!ad_schoolUnlocked() && item_amount($item[Dreadsylvanian skeleton key]) == 0 && !ad_getKey())
		{
			ad_debug("the schoolhouse is locked and a key needs 25 Freddy Kruegerands; collecting Freddies first");
		}
		else
		{
			ad_place square = ad_places()[4];
			if(!ad_schoolUnlocked())
			{
				ad_overrideProperty("choiceAdventure733", "1");	//the key opens the schoolhouse door for the clan
				ad_overrideProperty("choiceAdventure734", "2");
			}
			if(ad_recorded(square))
			{
				return ad_visit(square, new ad_plan(1, 734, 2, "the ghost pencil"));
			}
			return ad_fight("Village");
		}
	}
	//3. your action at each recorded place, by shortcut
	foreach i, p in ad_places()
	{
		ad_plan plan = ad_planFor(p);
		if(plan.top != 6 && plan.top != 5 && ad_recorded(p) && ad_zoneReachable(p.zone, sheets))
		{
			return ad_visit(p, plan);
		}
	}
	//4. fight where it helps most: the reachable zone furthest from done that the clan rule allows
	string best = "";
	foreach zone in $strings[Woods, Village, Castle]
	{
		if(ad_zoneReachable(zone, sheets) && ad_mayFight(zone) && (best == "" || ad_kills[zone] < ad_kills[best]))
		{
			best = zone;
		}
	}
	if(best == "")
	{
		ad_info("Nothing left to do: every reachable zone is at its boss or held back by the clan rule (don't take a zone to 100% before the others are near completion).");
		return false;
	}
	return ad_fight(best);
}

// What "autodread pencil" still has to do in this instance: collect this instance's pencil. "autodread map" also
// records a place with it (user, 2026-11-20): with a pencil in hand, fight where a place that isn't on the map, and that
// we haven't used this instance, can turn up. That waits on the place's noncombat, which can take a hundred fights or
// more (grimwiz, 2026-11-20: 108 in the Woods without the Tallest Tree), so plain "pencil" keeps the pencil for later.
boolean ad_pencilWorkLeft(boolean recordPlace)
{
	int sheets = ad_carriageSheets();
	if(recordPlace && ad_pencils() > 0)
	{
		foreach i, p in ad_places()
		{
			if(!ad_recorded(p) && !ad_placeUsed(p) && ad_zoneReachable(p.zone, sheets) && ad_mayFight(p.zone))
			{
				return true;
			}
		}
	}
	return ad_pencilWanted() && ad_zoneReachable("Village", sheets);
}

// The ghost pencil and the zones, then stop: the turns are wanted elsewhere (user, 2026-11-20: grimwiz levels in the
// sea to 15, does this, and goes back to the sea for Dad Sea Monkee).
void ad_runPencil(boolean recordPlace, int maxTurns)
{
	if(!ad_readLog())
	{
		ad_warn("Your clan has no Dreadsylvania instance open.");
		return;
	}
	int sheets = ad_carriageSheets();
	foreach zone in $strings[Village, Castle]
	{
		if(!ad_zoneReachable(zone, sheets))
		{
			ad_carriage(sheets, zone);
			sheets = ad_carriageSheets();
		}
	}
	int start = my_turncount();
	int reserve = ad_setting("advReserve", "0").to_int();
	int stuck = 0;
	while(true)
	{
		if(maxTurns >= 0 && my_turncount() - start >= maxTurns)
		{
			ad_info("Reached the " + maxTurns + "-turn limit.");
			break;
		}
		if(!ad_readLog())
		{
			ad_warn("Your clan has no Dreadsylvania instance open.");
			break;
		}
		if(!ad_pencilWorkLeft(recordPlace))
		{
			ad_info(!ad_anyUnrecorded() ? "Every place is on your map."
				: recordPlace ? "No place left to record in this instance." : "This instance's ghost pencil is collected.");
			break;
		}
		if(my_adventures() <= reserve)
		{
			cli_execute("autosea diet");
		}
		if(my_adventures() <= reserve)
		{
			ad_info("Out of adventures (reserve " + reserve + "), and nothing more worth eating or drinking.");
			break;
		}
		int before = my_turncount();
		if(!ad_turn())
		{
			break;
		}
		stuck = my_turncount() == before ? stuck + 1 : 0;
		if(stuck >= 3)
		{
			ad_warn("Three steps in a row spent no turn. Stopping so it doesn't spin.");
			break;
		}
	}
	ad_info("Spent " + (my_turncount() - start) + " turns on the pencil" + (ad_pencils() > 0 ? "; holding " + ad_pencils()
		+ " for the next place that isn't on your map." : "."));
}

void ad_run(int maxTurns)
{
	int start = my_turncount();
	int reserve = ad_setting("advReserve", "0").to_int();
	int stuck = 0;
	while(maxTurns < 0 || my_turncount() - start < maxTurns)
	{
		if(my_adventures() <= reserve)
		{
			cli_execute("autosea diet");	//eat and drink rather than stop (autosea fills the organs for every auto script)
		}
		if(my_adventures() <= reserve)
		{
			ad_info("Out of adventures (reserve " + reserve + "), and nothing more worth eating or drinking.");
			break;
		}
		int before = my_turncount();
		if(!ad_turn())
		{
			break;
		}
		stuck = my_turncount() == before ? stuck + 1 : 0;
		if(stuck >= 3)
		{
			ad_warn("Three steps in a row spent no turn. Stopping so it doesn't spin.");
			break;
		}
	}
	ad_info("Spent " + (my_turncount() - start) + " turns.");
}

void main(string... args)
{
	string joined = "";
	foreach i, a in args
	{
		joined += " " + a;
	}
	string[int] words = (joined == "" ? "" : joined.substring(1)).to_lower_case().split_string(" ");
	if(words[0] == "status")
	{
		ad_status();
		return;
	}
	if(words[0] != "" && words[0] != "pencil" && words[0] != "map" && words[0].to_int() <= 0)
	{
		ad_warn("Usage: autodread [turns] | autodread pencil [turns] | autodread map [turns] | autodread status");
		return;
	}
	int turns = words[0] == "" || words[0] == "pencil" || words[0] == "map" ? -1 : words[0].to_int();
	// KoL turns everyone below level 15 away ("You must be at least level 15 to handle this spooky place."), and
	// KoLmafia doesn't recognise that page, so say so here rather than fail at the first adventure.
	if(my_level() < 15)
	{
		ad_warn("Dreadsylvania needs level 15 and you're level " + my_level() + ", so there's nothing to do there yet.");
		return;
	}
	try
	{
		ad_overrideProperty("choiceAdventureScript", "");
		if(words[0] == "pencil" || words[0] == "map")
		{
			int limit = count(words) > 1 && words[1].to_int() > 0 ? words[1].to_int() : -1;
			ad_runPencil(words[0] == "map", limit);
		}
		else
		{
			ad_run(turns);
		}
	}
	finally
	{
		ad_restoreProperties();
	}
}
