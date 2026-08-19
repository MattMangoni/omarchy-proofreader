import io
import subprocess
import unittest
from unittest.mock import patch

import proofread


class PrerequisiteErrorsTest(unittest.TestCase):
    def run_main(self):
        with patch("sys.stdin", io.StringIO('{"text":"Hello","language":"en"}\n')):
            with self.assertRaises(SystemExit) as error:
                proofread.main()
        return error.exception.code

    @patch("proofread.shutil.which", return_value=None)
    def test_missing_claude(self, _which):
        self.assertEqual(self.run_main(), "CLAUDE_NOT_INSTALLED")

    @patch("proofread.shutil.which", return_value="/usr/bin/claude")
    @patch("proofread.subprocess.run")
    def test_logged_out(self, run, _which):
        run.side_effect = [
            subprocess.CompletedProcess([], 1, "", ""),
            subprocess.CompletedProcess([], 0, '{"loggedIn":false}', ""),
        ]
        self.assertEqual(self.run_main(), "CLAUDE_NOT_AUTHENTICATED")


if __name__ == "__main__":
    unittest.main()
