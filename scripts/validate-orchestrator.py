#!/usr/bin/env python3
"""Select local validation for the committed revision under review."""

import os
from pathlib import Path
import shutil
import subprocess

WORKER = [
    ("npm", "ci", "--prefix", "worker"),
    ("npm", "--prefix", "worker", "run", "typecheck"),
    ("npm", "--prefix", "worker", "test"),
]
DASHBOARD = [
    ("npm", "ci", "--prefix", "admin"),
    ("npm", "--prefix", "admin", "run", "check"),
    ("npm", "--prefix", "admin", "run", "build"),
    ("npm", "--prefix", "admin", "test"),
]
FULL = [WORKER[0], ("./scripts/validate.sh",)]

UI_ASSETS = {
    "WelcomeGym.imageset": "--ui-welcome",
    "OneSetLogo.imageset": "--ui-welcome",
}
IOS_SCOPES = {
    "OneSet/Features/History/HistoryModel.swift": (
        "OneSetTests/HistoryModelTests", None,
    ),
    "OneSet/Features/History/HistoryScreen.swift": (
        "OneSetUITests/OnboardingJourneyTests/testHistoryPreviewRoutesShowPopulatedPartialEmptyAndRetryStates",
        "--ui-history-populated",
    ),
    "OneSet/Features/Onboarding/TrainingPreferencesScreen.swift": (
        "OneSetUITests/OnboardingJourneyTests/testPreferencesRetainChoicesOnBackAndResetAfterRelaunch",
        "--ui-preferences",
    ),
    "OneSet/Features/Programs/WorkoutTemplatePreviewScreen.swift": (
        "OneSetUITests/OnboardingJourneyTests/testWorkoutPreviewOpensDifferentExerciseGuidanceWithoutStartingWorkout",
        "--ui-workout-preview",
    ),
    "OneSet/Features/Programs/RestCountdownView.swift": (
        "OneSetUITests/InlineRestTimerTests", "--ui-main-workout-recording",
    ),
}


def validation_plan(paths):
    """Return the local commands for the set of paths changed by a ticket."""
    files = sorted({path for path in paths if not path.endswith(".md")})
    if not files:
        return []
    if all(path.startswith("worker/") for path in files):
        return WORKER
    if all(path.startswith("admin/") for path in files):
        if any(path.startswith(("admin/src/repository-sync", "admin/src/middleware")) for path in files):
            return DASHBOARD + WORKER
        return DASHBOARD

    selectors = set()
    routes = set()
    full = False
    for path in files:
        if path in IOS_SCOPES:
            selector, route = IOS_SCOPES[path]
            selectors.add(selector)
            if route:
                routes.add(route)
        elif path.startswith("OneSet/Assets.xcassets/") and path.split("/")[2] in UI_ASSETS:
            routes.add(UI_ASSETS[path.split("/")[2]])
        else:
            full = True

    if full:
        commands = FULL.copy()
    elif selectors:
        commands = [("./scripts/validate.sh", "--focused", *sorted(selectors))]
    else:
        commands = []
    return commands + [("./scripts/validate-ui.sh", route) for route in sorted(routes)]


def main():
    base = os.environ["ISSUE_ORCHESTRATOR_BASE"]
    head = os.environ["ISSUE_ORCHESTRATOR_HEAD"]
    artifacts = Path(os.environ["ISSUE_ORCHESTRATOR_ARTIFACTS"])
    changed = subprocess.check_output(
        ["git", "diff", "--name-only", "--no-renames", "-z", base, head, "--"]
    )
    commands = validation_plan(os.fsdecode(changed).split("\0")[:-1])
    if not commands:
        print("Documentation-only change. CI and independent review still run.", flush=True)
    for command in commands:
        print("==> " + " ".join(command), flush=True)
        if command[0] == "./scripts/validate-ui.sh":
            filename = f"{command[1][5:]}-iphone.png"
            screenshot = Path(".codex", "screenshots", filename)
            if screenshot.exists():
                screenshot.unlink()
            subprocess.run(command, check=True)
            shutil.copyfile(screenshot, artifacts / filename)
        else:
            subprocess.run(command, check=True)


if __name__ == "__main__":
    main()
