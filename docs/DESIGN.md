# EERIE TALES - Episode 1: Eerie Springs Gas - Design Doc (Tony, 2026-11-02)

Series title: EERIE TALES (approved by Tony). Short first-person horror games like Fears to Fathom, true-inspired (names/details changed) + made-up stories.

## Core
- First-person horror, no weapons. Tools: flashlight, handheld barcode scanner.
- Length ~1.5 hours, slow burn. Goal is mainly to be scared; nothing physical beyond creepy customers attempting to grab you.
- Protagonist: Jake, new night-shift clerk. Makes small spoken/subtitle remarks when strange things happen.

## Setting
- EERIE SPRINGS GAS, rural Appalachia, at night.
- Store surrounded by very thick Appalachian forest. One straight road in front.
- Gas pumps out front; customers can pull up and self-checkout at pumps. Strange things sometimes happen with customers outside.
- Dark space behind the coolers (walk-in) with an alarm that sometimes needs shutting off.

## Opening
- Short cutscene: Jake pulls his car into the lot and gets out, transitions seamlessly into first person, gameplay begins.

## Gameplay loop
- Clean the store and do routine upkeep chores through the night.
- Customers come in periodically, bring items to the register; scan with hand scanner; working cash register with real money and change.
- Customers leave after their interaction/purchase.
- Dialogue with customers ranging from normal to weird/scary.

## NPCs
- Many varied NPCs: differ in height, race, age, gender, clothing. Some recur and take part in the story.
- NPC navigation AI (pathfinding/avoidance).
- Good-looking AI-generated faces.

## Key story beat
- Elderly, creepy man in period-appropriate/fitting attire offers Jake candy. Jake accepts. His joy turns serious: "You should never take candy from strangers." He leaves; seemingly nothing happens. Paranormal activity escalates afterwards.

## Paranormal events
- Start subtle (a light flickers) and escalate.
- Randomizer picks different paranormal events each run.
- Examples: lights flickering, alarm behind the coolers, whispering, "Excuse me" from a dark corner with nobody there.
- Scattered scream jumpscares during scary moments.

## Look
- GTA San Andreas / RenderWare PS2-to-PS3 era look. Not blocky. Good-looking faces.

## Open
- Tony welcomes extra ideas.

## Ending (approved)
- Dawn. The day clerk (a woman) arrives, sees Jake exhausted: "Damn Jake, you look like hell..." Jake ignores her completely, walks to his car, and drives off into the sunrise down the straight road through the woods.

## Extra ideas (APPROVED by Tony 2026-11-02 unless noted)
- Manager's rules note by the register; landline phone with increasingly strange calls (one in Jake's own voice).
- Security camera monitors showing people who aren't there / the old man at the pumps.
- Wall clock tracking the 10 PM - 6 AM shift; time skips near the end.
- REJECTED by Tony: candy wrappers appearing as a callback.
- REPLACED: "store closed for years" ending (Tony chose the ending above).
- Security monitor detail (Tony): a small security TV at the front desk next to the register. Occasionally shows a quick glimpse of a long, lanky, horrifying creature that vanishes when the player looks directly at the screen (glimpse only in peripheral view).

## Onboarding hints (Tony, 2026-11-02)
- Small hints at the start so players know exactly what's going on: controls, flashlight, interacting, clock-in, manager's note, chore list, scanning, register and change, pump customers, first cooler alarm.
- Current-objective line. Hints show once, taper off later in the night, and have a settings toggle.

## Visual direction update (Tony, 2026-11-02)
- Graphics as crisp as possible with lots of detail: a high-detail, remastered take on the PS2/San Andreas style (sharp filtering, anti-aliasing, dense set dressing).
- Store looks like a typical American highway gas station chain (Fastrip-like), with invented branding only.


## Build notes (vertical slice 2026-11-02)
- Engine: Godot 4 standard. Project at `game/`.
- Visual target: remastered PS2 / San Andreas-era C-store — crisp textures, MSAA, dense highway-store set dressing, invented brands only.
- Onboarding: HintManager + objective line + Esc settings toggle for hints. Hints show once, taper after ~1 AM.
- No weapons. Tools: flashlight, barcode scanner, register/change.
