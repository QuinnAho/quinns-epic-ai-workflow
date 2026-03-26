---
description: Analyze a specification for completeness and clarity
---

Analyze a feature specification using the spec-analyst subagent.

## Arguments
- $ARGUMENTS: Path to the spec file to analyze

## Instructions

1. Read the specification file at the provided path

2. Launch the spec-analyst subagent to:
   - Check for completeness (all required sections present)
   - Assess clarity (unambiguous requirements)
   - Verify testability (measurable acceptance criteria)
   - Identify dependencies
   - Analyze risks

3. Report:
   - Completeness score (X/10)
   - List of missing elements
   - Ambiguous requirements with suggested clarifications
   - Requirements that cannot be objectively tested
   - Dependencies identified
   - Risks and concerns

4. Provide clear recommendation:
   - APPROVED: Ready for architecture phase
   - NEEDS REVISION: List specific issues to address

If no path is provided, list available specs in `.claude/specs/` and ask which to analyze.
