# Cooline 3.0

A lightweight cooldown timeline addon for **World of Warcraft 1.12.1**, based on the original [Cooline by shirsig](https://github.com/shirsig/cooline).
Cooline 3.0 is a re-write of my 2.0 version with ClassicAPI as a requirement for use. Use the `native-2.1` branch if you don't use ClassicAPI.

## About

Cooline displays active spell and item cooldowns on a simple timeline, making it easy to see which abilities are becoming available at a glance.

This fork intends to keep the genuinely excellent base behaviour, but has been completely re-written for stability and future development.

### Improvements

- **Removal of hard-coded user configuration** - New in-game configuration menu
- Account-wide appearance settings - optional per-character toggle
- Horizontal and vertical layouts fixed
- Configurable bar, icon and opacity settings
- Per-character spell and item filtering - blacklist and whitelist support
- Locale-scoped spell and item filters so changing client language does not mix incompatible localized names
- Locale-safe cooldown-failure animation without parsing English combat text
- Localized configuration text for supported Vanilla client locales, with English fallback
- Locale-aware UI font handling using the client's standard text font
- Timeline labels always render above cooldown icons
- Selectable timeline font: Client Default, Friz Quadrata, Arial Narrow, Morpheus or Skurri
- Font dropdown aligned with the Appearance controls and each entry previews its actual font
- Timeline font selection updates the actual bar labels immediately; Client Default follows the active Blizzard GameFont
- Font previews use a Cooline-owned popup and no longer modify Blizzard's shared dropdown menu buttons
- Cooldown icons render above the bar while timeline text uses its own higher frame strata so it renders above the icons
- Vanilla 1.12 FontStrings are assigned a font before text is set
- Opacity values are clamped to valid 0-100% values
- Minimap button to access options
- Bar lockable
- Right-click the Cooline bar to open options - Alt-click to reposition
- A few basic skins to start with
- Configurable animation when casting a spell on cooldown

## Development

Active development follows the VanillaTemplate workflow on the `dev` branch. Development versions use a `-dev` suffix and are promoted to a stable release only after explicit in-game verification.

## Compatibility

Designed for **World of Warcraft 1.12.1**.

Development and testing is primarily carried out on Vanilla 1.12.1 private-server clients.

### Cooldown Accuracy

Cooline 3.0 uses ClassicAPI spell and item identity on the supported use routes. One Vanilla action-bar bag-instance format can still surface without an itemID; Cooline keeps a narrow fallback for that case. Shared-cooldown testing confirms that when exact identity is available, Cooline keeps the item actually used as the displayed representative.

## Credits

Original Cooline created by **shirsig**.

This project builds upon the original Cooline addon while preserving its core design and functionality.
