# Cooline 1.9.8

A lightweight cooldown timeline addon for **World of Warcraft 1.12.1**, based on the original [Cooline by shirsig](https://github.com/shirsig/cooline).

## About

Cooline displays active spell and item cooldowns on a simple timeline, making it easy to see which abilities are becoming available at a glance.

This fork intends to keep the genuinely excellent base behaviour, but has been completely re-written for stability and future development.

### Improvements

- **Removal of hard-coded user configuration** - New In-game configuration menu
- Account-wide appearance settings - optional per-character toggle
- Horizontal and vertical layouts fixed
- Configurable bar, icon and opacity settings
- Per-character spell and item filtering - Blacklist and whitelist support
- Minimap button to access options
- Bar lockable
- Right-click the Cooline bar to open options - Alt-click to reposition
- A few basic skins to start with
- Configurable animation when casting spell on cooldown

## Version

The 1.9.x series is intended for development and testing. Once the redesigned addon is stable, it will become **Cooline 2.0.0**.

## Compatibility

Designed for **World of Warcraft 1.12.1**.

Development and testing is primarily carried out on Vanilla 1.12.1 private-server clients.

### Cooldown Accuracy

The WoW 1.12.1 client provides limited information for identifying some item cooldowns, particularly items which share cooldowns such as potions and on-use trinkets. Cooline uses best-effort tracking, but in some cases the displayed item may not be identified accurately.

## Credits

Original Cooline created by **shirsig**.

This project builds upon the original Cooline addon while preserving its core design and functionality.
