---
description: Validate implementation against its specification
---

Validate that an implementation meets all specification requirements.

## Arguments
- $ARGUMENTS: Path to the spec file to validate against

## Instructions

1. Read the specification file

2. Launch spec-validator subagent to:
   - Map each requirement to its implementation
   - Verify each acceptance criterion
   - Check integration with existing code
   - Confirm documentation updates

3. Run all tests and report results:
   ```bash
   npm test
   ```

4. Generate validation report:
   - Requirement traceability matrix
   - Acceptance criteria pass/fail status
   - Test results
   - Integration verification
   - Documentation status

5. Provide final verdict:
   - APPROVED FOR RELEASE: All requirements met
   - NOT APPROVED: List blocking issues and required actions

This is the final quality gate before marking a feature complete.
