---
description: Generate tests for specified files or features
---

Generate comprehensive tests using the spec-tester subagent.

## Instructions

1. Identify the target for testing:
   - If a file path is provided: test that specific file
   - If a feature name is provided: find related files and test them
   - If nothing specified: test recently changed files

2. Launch the spec-tester subagent to:
   - Generate unit tests for all public functions
   - Create integration tests for component interactions
   - Add edge case tests (nulls, boundaries, errors)
   - Write tests following Arrange-Act-Assert pattern

3. Run the generated tests:
   ```bash
   npm test
   ```

4. If mutation testing is available, run it:
   ```bash
   npx stryker run
   ```

5. Report:
   - Number of tests created
   - Coverage percentage achieved
   - Mutation score (if available)
   - Any failing tests that need attention

Target: 80% coverage, 80% mutation score on critical paths.
