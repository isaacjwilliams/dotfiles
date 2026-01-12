---
description: Debug a test that passes locally but intermittently fails in CI
---

The test at $1 passes locally, but fails intermittently in CI.

The failure in CI looks like:

```
$2
```

The full test suite runs in CI. We do not and cannot run the full test suite locally.

1. Thoroughly review the test and identify any possible causes of intermittent failure in CI.
2. Ultrathink about what logging, if captured in CI, would definitively reveal the root cause of the failure.
3. Present your findings from steps 1 and 2 in chat, starting with possible causes, finishing with an outline of the logging that would definitively reveal the root cause of failure when the test fails in CI.

If the user requests that you add the logging you thought of in step 2 and outlined to them in step 3, ensure that the logging you add makes no noise outside of CI. Add a prefix to the logs so they are easy to search for in test output. Try to keep logging isolated to the failing test, if possible. Write a new Markdown doc to the docs/ci_failures directory describing: theoretical causes of the failure and (per theoretical cause) the logging added to validate/invalidate the theory, so a later agent can read the docs and the logs from CI and know what he's looking for.

Additional guidance: when adding CI-only debug logging for these failures, use `puts` (STDOUT) behind the `ENV['CI']` gate rather than `Rails.logger`, so only the targeted debug lines appear in CI test output without enabling full Rails logging.
