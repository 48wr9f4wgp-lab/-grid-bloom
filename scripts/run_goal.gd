class_name GridRunGoal
extends RefCounted

const MILESTONE_STEP := 500

static func target_for(score: int, run_start_best: int) -> int:
    var next_milestone := ((maxi(score, 0) / MILESTONE_STEP) + 1) * MILESTONE_STEP
    if run_start_best > score and run_start_best - score <= MILESTONE_STEP:
        return run_start_best
    if run_start_best > score:
        return mini(run_start_best, next_milestone)
    return next_milestone

static func label_for(score: int, run_start_best: int) -> String:
    var target := target_for(score, run_start_best)
    var remaining := maxi(0, target - score)
    if run_start_best > score and target == run_start_best:
        return "BEST IN %d" % remaining
    return "TARGET %d  •  %d TO GO" % [target, remaining]

static func is_near_best(score: int, run_start_best: int) -> bool:
    if run_start_best <= 0 or score >= run_start_best:
        return false
    var gap := run_start_best - score
    var window := maxi(140, int(round(float(run_start_best) * 0.12)))
    return gap <= window

static func result_title(score: int, run_start_best: int) -> String:
    if run_start_best > 0 and score > run_start_best:
        return "NEW BEST"
    if is_near_best(score, run_start_best):
        return "SO CLOSE"
    return "RUN COMPLETE"

static func result_subtitle(score: int, run_start_best: int) -> String:
    if run_start_best <= 0:
        return "FIRST SCORE ON THE BOARD"
    if score > run_start_best:
        return "+%d ABOVE YOUR BEST" % (score - run_start_best)
    if score == run_start_best:
        return "MATCHED YOUR BEST"
    return "%d TO BEAT YOUR BEST" % (run_start_best - score)

static func retry_cta(score: int, run_start_best: int) -> String:
    if run_start_best > 0 and score > run_start_best:
        return "PUSH IT HIGHER"
    if is_near_best(score, run_start_best):
        return "BEAT YOUR BEST"
    return "PLAY AGAIN"
