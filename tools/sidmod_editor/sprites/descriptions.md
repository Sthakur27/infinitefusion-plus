# Sprite descriptions — the 13 fusions in File A with no custom art

Step 1 of the two-step pipeline: deep aesthetic description → image gen → `spritefit.py`.

IF convention: **head donor** gives the head, face, crest/horns, ears and the head's colour
identity. **Body donor** gives the torso, limbs, tail, wings and overall posture. Good customs
bleed a little of the head's palette down into the body so the two halves read as one animal.

Each entry carries a `box` (target footprint on the 96 grid — feed it to `spritefit.py --box`)
and a palette budget. **Real sprites use 12–16 colours, median 14.** That is the single hardest
constraint for a generative model and the descriptions are written to respect it: every entry
names 3–4 shading ramps of 3 steps each, plus black outline and 1–2 accent colours.

Shared style block, prepend to every prompt:

> Gen-5 Pokémon Black/White style battle sprite, front view, single character, full body,
> hard 1px black outline, cel shading in flat colour bands with no gradients and no dithering,
> light source upper-left, no anti-aliasing, no background, transparent, no ground shadow,
> no text, no border.

---

## 1. Heracross / Armaldo — `214.304`, L87, Apple Woods · box `72x62`

An armoured beetle-crustacean built like a siege engine. The head is Heracross': glossy
blue-black chitin, oval lemon-yellow eyes with no pupils, cream mandible plates flanking a small
hard mouth, and the single enormous horn sweeping forward off the brow and splitting into a
two-pronged Y at the tip. The horn is the silhouette — it should read from across the room.
Below the neck it becomes Armaldo: a warm grey-tan segmented carapace in overlapping bands down
the chest, two oversized scythe-claw arms held wide and low, stubby splayed legs, and a fanned
segmented tail just visible behind. Posture is a forward-leaning charge, weight on the front,
head dipped so the horn levels at the viewer. Where the blue-black head meets the tan shell,
run two or three transitional plates that carry the blue tint so the join isn't a seam.

Ramps: blue-black chitin (near-black → indigo → slate highlight), tan carapace (dark umber →
mid tan → bone highlight), cream plate (shadow ecru → cream → white), yellow eye accent.

## 2. Breloom / Whimsicott — `355.360`, L68, Apple Woods · box `44x42`

Small, round and top-heavy — this one is cute, not fearsome. The head is Breloom's flat green
mushroom cap, a wide low dome with scattered round tan spots on top, overhanging a broad beaky
mouth curved into a permanent grin and small round eyes with red rims. Under the cap the body is
pure Whimsicott: a fat cloud of off-white cotton, wider than it is tall, its outline drawn as a
series of soft overlapping lobes rather than a smooth circle. Two stubby brown limbs poke out
below, barely long enough to see, and two green cotton tufts curl off the sides like leaves.
Posture is a standing bounce — feet together, body tilted slightly back, as if it just landed.
Let a few green flecks from the cap settle into the top of the cotton.

Ramps: cap green (forest → grass → pale lime), cotton white (grey-lavender shadow → off-white →
white), tan spots (brown → tan), red eye rim accent.

## 3. Marowak / Scizor — `105.212`, L40, Haina Desert · box `58x60`

A red steel warrior wearing a skull. The head is Marowak's bone helmet — smooth cream-white,
domed, with two dark hollow eye sockets that each hold a single small bright pupil, and the
lower jaw of the real face visible beneath the helmet rim in dull brown. Body is Scizor's:
a hard crimson exoskeleton in polished segmented plates, broad flat chest, and the two huge
pincer claws — each a blunt round mitt with a black-and-yellow eye marking on its face — held up
in a boxer's guard. Two small translucent grey wings sit tight against the back. Legs are thin
red steel with sharp knee joints. Give it Marowak's bone club, gripped in the right pincer,
held low. The bone cream of the helmet should echo in a thin trim along the shoulder plates.

Ramps: crimson steel (maroon → red → orange-red highlight), bone cream (grey-tan → cream →
white), dark socket (black → charcoal), yellow claw marking accent.

## 4. Banette / Hydreigon — `357.377`, L100, Crystal Cave · box `80x66`

A floating marionette-hydra, and the best of the thirteen if it lands. The head is Banette's:
a flat grey-violet cloth doll head, roughly wedge-shaped, dominated by a heavy metal zipper
running across where the mouth should be, teeth of the zipper picked out in pale grey. Eyes are
narrow yellow slits with no pupils. A single stubby tab or spike sticks up off the crown. The
body is Hydreigon — a dark navy-indigo hovering torso with no legs at all, six small black
membranous wings fanned in two tiers, and the two side-arm heads on either side. Make those two
side heads cloth and zippered as well, smaller echoes of the main head, so the theme carries.
Posture floats: body tilted forward, tail-stub trailing, nothing touching the ground. Bottom of
the sprite should be the trailing tail, not feet.

Ramps: navy body (near-black indigo → navy → periwinkle highlight), violet-grey cloth (dark
plum → grey-violet → pale lilac), zipper grey (charcoal → silver → white), yellow eye accent.

## 5. Qwilfish / Octillery — `211.224`, L76, Deep Abyss · box `56x58`

A spined pufferfish head sitting on an octopus. The head is Qwilfish's: a near-spherical dark
navy-green ball, bristling all over with short straight cream-white spines that radiate outward
in every direction, two very large round yellow eyes set wide on the front, and a small puckered
mouth between them. The spines are the silhouette — keep them crisp and individually readable,
not a fuzzy halo. Below it, Octillery's body: a soft red-orange conical mantle, then a skirt of
six thick tapering tentacles splayed outward and curling at the tips, with pale cream suckers
along the undersides. Posture sits low and planted, tentacles spread like a tripod. Let the
navy-green of the head darken the top of the mantle where the two meet.

Ramps: navy-green head (deep teal-black → sea green → pale green), red-orange mantle (brick →
orange-red → coral highlight), cream (tan → cream → white) for spines and suckers, yellow eye.

## 6. Kingdra / Empoleon — `230.324`, L100, Rain · "Hydroking" · box `58x70`

Regal, vertical, and the most "royal" of the set — lean into emperor imagery. The head is
Kingdra's: a pale blue seahorse head with a long tapering tubular snout, a small hard eye ringed
in gold, and two swept-back fanned head-fins flaring off the skull like a crown. The body is
Empoleon's: a tall upright penguin torso in dark steel-blue, a broad chest bearing a golden
trident-shaped marking, deep navy flipper-arms edged in yellow held slightly away from the sides,
and wide yellow feet. Posture is bolt upright and still — chin up, chest out, motionless. Tall
and narrow, this is the one sprite that should nearly fill the vertical box. The pale blue of the
head should carry down as a lighter throat and chest gradient before the steel-blue takes over.

Ramps: pale seahorse blue (steel blue → sky → near-white), deep navy (midnight → navy → slate
highlight), gold (bronze → gold → pale yellow), dark fin membrane accent.

## 7. Vaporeon / Registeel — `134.449`, L100, Bench · box `56x66`

A chrome golem wearing an aqua fish-cat head. Head is Vaporeon's: smooth aqua-blue, a rounded
feline muzzle with a small dark nose, big dark eyes, three-pointed cream frill under the chin,
and the split fish-fin ears standing up off the skull with a dark navy webbed crest running back
between them. The body is Registeel: a bulbous, neckless, hunched torso of dark polished steel,
thick smooth tubular arms hanging down to blunt round hands, and short heavy legs — no visible
joints anywhere, everything liquid-smooth. The trick here is the palette: tint the steel toward
Vaporeon's aqua so it reads as wet polished chrome rather than grey, and let the cream frill
repeat as a band across the chest where Registeel's dot pattern would be. Posture is a heavy
symmetrical stand, arms slack at the sides.

Ramps: aqua (deep teal → aqua → pale cyan), tinted steel (charcoal-blue → blue-grey → bright
silver-cyan highlight), cream frill (tan → cream → white), navy crest accent.

## 8. Skarmory / Ferrothorn — `227.364`, L100, OU · box `62x64`

Head is Skarmory's: a sleek silver-grey steel bird skull, long sharp downcurved beak in darker
gunmetal, eyes small and yellow set in a red-rimmed socket, with swept plated crest feathers
pinned back along the head. Body is Ferrothorn: a squat spherical shell of grey-green iron, its
whole surface studded with short conical spikes, and three long thorny vine tendrils hanging
down from beneath — each tapering, each capped with a heavy three-pointed thorn head, one curled
inward and two trailing. No legs; the body hangs, so the vine tips are the lowest thing in the
sprite. Posture: the bird head juts forward and slightly down off the top of the sphere, giving
the whole thing a hunched, watchful, gargoyle-like read. Carry Skarmory's silver into the
spike tips so the shell doesn't look like a separate object.

Ramps: silver steel (gunmetal → steel grey → white highlight), iron green (dark olive-black →
grey-green → sage), thorn (dark bronze → tan), red socket + yellow eye accents.

## 9. Espeon / Metagross — `196.293`, L100, OU · box `74x54`

Low, wide, four-legged and heavy — the only quadruped in the set, so play the silhouette against
the others. Head is Espeon's: a delicate lilac cat head, large slanted violet eyes with pale
pupils, long forked ears splitting into two points each, a fine muzzle, and the red gem set flat
in the centre of the forehead. Body is Metagross': a massive squat chassis of blue-teal steel,
four thick tapering legs planted wide with clawed feet, and a broad flat back. Keep Metagross'
weight but recolour the steel to a violet-tinged blue so the lilac head belongs on it. Run a thin
gold or cream seam along the plate joins. Posture is a low stalk — body level, head lowered
between the shoulders, one front paw very slightly forward. Wide and flat; this sprite should be
noticeably wider than it is tall.

Ramps: lilac (mauve shadow → lilac → pale pink-white), violet steel (indigo → blue-teal →
pale cyan highlight), gold seam (bronze → gold), red gem accent.

## 10. Raikou / Latios — `243.379`, L100, Ubers · "Voltseer" · box `80x54`

A thunder-jet with a tiger's head. Head is Raikou's: bright saffron-yellow fur, a black mask
band across the eyes, white fanged muzzle open in a snarl, red eyes, and the distinctive grey
X-shaped crest plate sitting on the brow above the eyes. The purple storm-cloud mane should be
present but trimmed back to a swept crest that streams behind rather than the full ruff — it
needs to read as aerodynamic. Body is Latios': a sleek blue-and-white jet-dragon, white
underside and chest, deep blue back and delta wings swept sharply back, small arms tucked tight
against the body, tapering to a pointed tail. Nothing touches the ground — this one hovers,
tilted nose-down toward the viewer in a diving posture, wings wide. Widest sprite of the set.
Bring the yellow down as a lightning-stripe flash along the leading edge of each wing.

Ramps: saffron (amber → yellow → pale cream), deep blue (navy → royal blue → sky highlight),
white underside (blue-grey shadow → off-white → white), purple mane + red eye accents.

## 11. Meloetta / Genesect — `467.348`, L100, Squads 3 · box `62x60`

A war machine with a singer's head, and the contrast is the whole point — keep the head small,
soft and detailed against a body that is blocky and industrial. Head is Meloetta's: a small
pale-cream face with very large round black eyes, a tiny mouth, and the green hair swept up and
around into two long curling locks shaped like musical notes, one falling either side. Body is
Genesect's: a purple insectoid mech torso in hard flat armour plates, thick segmented arms
ending in blunt claws, digitigrade armoured legs, and the heavy cannon mounted across the upper
back with its muzzle visible over one shoulder. Posture is a braced stand, legs apart, arms out
from the body — machine at rest. Let the green of the hair-notes reappear as glowing seams
between the purple armour plates and as the cannon's energy glow.

Ramps: purple armour (dark violet → purple → lavender highlight), green (deep teal-green →
green → pale mint) for hair and seams, cream face (tan shadow → cream → white), black eye +
red visor accents.

## 12. Palkia / Volcarona — `344.374`, L100, OU · box `86x66`

The biggest silhouette here — a moth-dragon, pearl and fire. Head is Palkia's: a white pearlescent
dragon skull, narrow and pointed, with twin swept crest fins rising off the back of the head,
gold-rimmed eyes with slit pupils, and the soft pink accent panels along the jaw. Body is
Volcarona's: a thick fuzzy white thorax and abdomen, densely furred, with six broad wings in two
tiers spread wide — the upper pair large, the lower pair smaller — each wing white at the base
grading to burning orange at the edges with dark red flame-eye markings. Six small dark legs
tucked beneath. Posture is wings fully spread, hovering, body angled slightly forward. Palkia's
pink should tint the fur at the collar and the wing bases so the fire looks like it's igniting
out of the pearl rather than pasted on.

Ramps: pearl white (grey-violet shadow → off-white → white), fire (dark red → orange → yellow),
pink accent (rose → pale pink), gold eye rim + dark leg accents.

## 13. Darkrai / Reshiram — `347.349`, L100, Ubers · box `76x72`

Light and shadow on one body — the strongest concept of the thirteen. Head is Darkrai's: a
smooth featureless black head with no visible mouth, a single piercing pale-blue eye, and the
white shadow-plume of "hair" streaming up and to one side in a ragged smoke-like sweep. The red
spiked collar sits at the base of the neck. Body is Reshiram's: a powerful white feathered
dragon — broad feathered chest, muscular arms ending in clawed hands, large feathered wing-arms
spread, thick legs, and the great turbine tail behind, ringed and burning faintly at its centre.
Posture is standing tall and open, wings half-spread, chest forward. The join is the concept:
let the black bleed down the neck into the chest feathers as a smoky gradient, tipping the
nearest feathers charcoal so the white dragon looks like it's being consumed from the head down.

Ramps: white feather (blue-grey shadow → off-white → white), black smoke (pure black → charcoal
→ grey), blue eye + turbine glow (deep blue → cyan → white), red collar accent.
