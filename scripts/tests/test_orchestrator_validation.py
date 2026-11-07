import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

# The script filename is also the command documented in the project config.
from importlib import import_module
validation_plan = import_module("validate-orchestrator").validation_plan


class OrchestratorValidationTests(unittest.TestCase):
    def test_docs_only(self):
        self.assertEqual(validation_plan(["docs/requirements.md"]), [])

    def test_welcome_artwork_runs_visual_validation_only(self):
        self.assertEqual(
            validation_plan(["OneSet/Assets.xcassets/WelcomeGym.imageset/welcome-gym.png"]),
            [("./scripts/validate-ui.sh", "--ui-welcome")],
        )

    def test_preferences_screen_runs_behavior_and_visual_validation(self):
        self.assertEqual(
            validation_plan(["OneSet/Features/Onboarding/TrainingPreferencesScreen.swift"]),
            [
                ("./scripts/validate.sh", "--focused",
                 "OneSetUITests/OnboardingJourneyTests/testPreferencesRetainChoicesOnBackAndResetAfterRelaunch"),
                ("./scripts/validate-ui.sh", "--ui-preferences"),
            ],
        )

    def test_worker_changes_run_worker_checks(self):
        commands = validation_plan(["worker/src/history.ts"])
        self.assertIn(("npm", "--prefix", "worker", "test"), commands)
        self.assertNotIn(("./scripts/validate.sh",), commands)

    def test_dashboard_sync_changes_run_both_package_checks(self):
        commands = validation_plan(["admin/src/repository-sync.ts"])
        self.assertIn(("npm", "--prefix", "admin", "test"), commands)
        self.assertIn(("npm", "--prefix", "worker", "test"), commands)

    def test_mixed_changes_keep_full_and_visual_validation(self):
        commands = validation_plan([
            "worker/src/history.ts", "OneSet/Features/History/HistoryScreen.swift",
        ])
        self.assertIn(("./scripts/validate.sh",), commands)
        self.assertIn(("./scripts/validate-ui.sh", "--ui-history-populated"), commands)
