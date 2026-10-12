A translucent pill-shaped bar that floats above content, used for the phone tab bar and for toolbars over a photo grid.

- `glass-fill` over a `blur-glass` backdrop blur, a 1px `glass-stroke` edge, `shadow-glass` and `radius-xl`.
- It is inset from the screen edges by `space-4`, and content scrolls beneath it.
- The current item is an `accent-soft` pill with `accent` text. Items are at least `control-height` tall; a tab bar holds five at most.
- **Reduced transparency, the web build and slow devices:** the fill is `surface` with `shadow-2` and no blur.
- Nothing else in the system is glass.
- You provide the items and which one is current.
