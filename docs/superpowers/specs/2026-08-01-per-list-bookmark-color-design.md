# Per-list bookmark color

Fixes mortenfyhn/organicmaps#4. Related upstream discussion: organicmaps/organicmaps#1805.

## Problem

Every new bookmark takes its color from `BookmarkManager::LastEditedBMColor()` — a single
global "last color used", defaulting to red. It is not scoped to a list. Change one bookmark
to blue and every subsequent bookmark, in every list, is blue.

Anyone keeping several lists (attractions, campsites, birding sites) has to set the color by
hand on every bookmark they save.

Upstream already shipped half the fix: list settings has a **Change color of all bookmarks**
button that calls `BookmarkManager::EditSession::SetCategoryBookmarksColor(groupId, color)`
and recolors every bookmark in the list. The color is not remembered, so bookmarks added
afterwards do not get it.

## Behavior

- A list can have a bookmark color. Lists have none by default and behave exactly as today.
- The existing **Change color of all bookmarks** button recolors every bookmark in the list
  (as today) and stores the color on the list.
- A new bookmark saved into a list that has a color gets that color instead of the global
  last-used color.
- A bookmark moved into a list that has a color gets that color.
- Bookmarks imported from KML/GPX keep their own colors. Re-picking the list's color runs the
  bulk recolor and pulls them into line.
- A single bookmark can still be recolored by hand, and stays that way until the next bulk
  recolor.
- The button shows the list's current color as a swatch, and is visible even when the list is
  empty (today it is hidden until the list has at least one bookmark).

Lists without a color are untouched, so this is opt-in and backwards compatible.

### Naming

The stored property is `bookmarksColor`, not `color`. A list has two independent bulk-recolor
buttons, one for bookmarks and one for tracks, so a bare "color" would be ambiguous. A
`tracksColor` property can be added later without renaming anything. Nothing user-facing
changes: the UI keeps its existing wording.

## Implementation

### Storage

`kml::CategoryData::m_properties` is a `std::string -> std::string` map that already
round-trips through both .kml (`SaveStringsMap`, serdes.cpp:318) and .kmb (via
`DECLARE_VISITOR`). Store the color there as a hex RGBA string under `bookmarksColor`.

No file format version bump, and lists written by this build stay readable by upstream builds
(they ignore the unknown property).

Absence of the property means "no list color".

### Core (libs/)

| Location | Change |
| --- | --- |
| `libs/kml/types.hpp` | Free functions to get/set the `bookmarksColor` property on a `CategoryData` |
| `libs/map/bookmark_manager.cpp` `SetCategoryBookmarksColor` | Also write the property |
| `libs/map/bookmark_manager.cpp` `CreateBookmark(bmData, groupId)` | If the target list has a color, use it instead of the incoming one |
| `libs/map/bookmark_manager.cpp` `MoveBookmark` | Same, for the destination list |

`MoveBookmark` is hooked rather than `AttachBookmark` so the import path stays untouched by
construction: importing a file builds its bookmarks with the single-argument
`CreateBookmark(bmData)` followed by `bm->Attach(groupId)` (bookmark_manager.cpp:2845),
bypassing both hooked functions.

No color read path changes — rendering, list rows and the place page keep reading
`BookmarkData::m_color`. No new JNI methods.

### Android

`BookmarkCategorySettingsFragment.java`:

- Show the list's current bookmark color as a swatch on the button.
- Drop the `bookmarksCount > 0` condition that hides the button, since it now also sets a
  default for future bookmarks.

### Tests

`libs/map/map_tests/bookmarks_test.cpp`:

- A new bookmark saved into a list with a color gets that color.
- A new bookmark saved into a list without a color keeps the global last-used behavior.
- Moving a bookmark into a list with a color recolors it.
- The property survives a save/load round-trip.

## Upstreaming

This matches points 3.2 and 4 of the spec quoted in organicmaps#1805, and being opt-in it
answers the maintainer's objection there ("it's clear to users that every added bookmark has
the same last used color; breaking that may confuse users") — nothing changes for a list with
no color.

Not in scope for upstream as written: nothing. The one rule that would likely draw pushback,
imports adopting the list color, was deliberately left out.

## Out of scope

- Tracks. The track bulk-recolor button stays a one-shot.
- Auto-assigning colors to new lists.
- Deriving bookmark colors from POI type.
