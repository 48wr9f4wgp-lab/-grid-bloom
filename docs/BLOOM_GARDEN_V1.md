# Bloom Garden v1

## Goal
Turn persistent Bloom Level progress into a visible, always-present garden identity without adding currencies, shops, timers, collection taps, or power advantages.

## Player-facing rule
- The garden grows automatically when Bloom Level rises.
- Growth is cosmetic and never changes placement rules, board state, piece generation, scoring fairness, or fail conditions.
- The garden lives around the play board rather than behind a separate menu.

## Growth stages
| Bloom Level | Stage | Visual change |
| --- | --- | --- |
| 1-2 | Seedling | Small sprouts and first leaves |
| 3-4 | Vines | Vines begin wrapping the board frame |
| 5-7 | Blossom | Flowers appear and density rises |
| 8-11 | Garden | The frame becomes a fuller living garden |
| 12+ | Starlight | Full garden plus subtle animated fireflies |

Each Bloom Level within a stage adds more persistent plant details, so every level-up changes the scene even when the named stage does not change.

## Feedback
- Crossing a stage threshold shows a short `GARDEN • <STAGE>` celebration.
- Newly unlocked plants grow in with a short scale-in animation.
- Stage transition emits analytics event `garden_stage_up`.

## Non-goals for v1
- No garden screen.
- No garden currency.
- No decorating inventory.
- No monetized cosmetics.
- No gameplay buffs.

These can only be considered after the passive garden proves it improves return motivation without distracting from the block puzzle core.
