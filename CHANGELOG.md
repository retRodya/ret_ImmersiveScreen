# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Settings window: General, Effects (HideUI, Letterbox, CameraShift, FOV), Lens
  and LiteRP (GoOffline, GoOnline) in a list on the left, the selected page on the right.
- `/retis` and `/retimmersivescreen`, the Addon Compartment and the addon's page
  in Settings > AddOns open the window.
- Effects turn on or off with a checkbox in the list after `/reload`. Their settings
  apply at once; an undo button restores any value changed since the last reload.
- HideUI hides the interface exactly like Alt+Z, and the names you choose.
  Its page lists only the names the game's settings show, each checked by default.
  Names go and come back one setting at a time, so there is no FPS spike.
- While an effect is on, the first Escape turns off every effect; the next one
  opens the game menu as usual.
- Letterbox slides black bars in and out at the top and bottom of the screen.
  Bar height and animation duration are adjustable.
- Lens page: a key for each effect and for the Combined Lens. Keys also appear
  in Key Bindings under ret_ImmersiveScreen.
- General: Hide screenshot message hides the "Screen captured" text.
- CameraShift smoothly moves the camera to the side, with adjustable offset and
  animation duration, on its own key.
- FOV smoothly changes the camera's field of view and returns it to yours, with
  adjustable angle and animation duration, on its own key.
- GoOffline closes the Letterbox bars in during the logout countdown, in three
  adjustable stages; cancelling the logout brings them back.
- GoOnline opens the Letterbox bars from the middle of the screen and fades
  them out after you enter the world. A Test button plays it at once.
- GoOffline and GoOnline have a Defaults button that sets their page back to
  its defaults.
