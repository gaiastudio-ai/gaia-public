# E28-S44 Compatibility Fixture — gaia-create-prd
#
# This fixture documents the structural contract between the legacy
# create-prd workflow and the native gaia-create-prd skill (E28-S40).
# The E28-S44 validation gate consumes this file to verify byte-compatibility
# of PRD artifacts produced by the new skill against the legacy workflow.
#
# Structural contract (section order must match legacy prd-template.md):
#   1. Overview
#   2. Goals and Non-Goals
#   3. User Stories
#   4. Functional Requirements
#   5. Non-Functional Requirements
#   6. Out of Scope
#   7. UX Requirements
#   8. Technical Constraints
#   9. Dependencies
#  10. Milestones
#  11. Requirements Summary
#  12. Open Questions
#
# Frontmatter contract (YAML shape):
#   template: 'prd'
#   version: 1.0.0
#   used_by: ['create-prd']
#
# Multi-step reasoning contract (legacy step order):
#   Step 1:  Load Product Brief
#   Step 2:  User Interviews
#   Step 3:  Functional Requirements
#   Step 4:  Non-Functional Requirements
#   Step 5:  User Journeys
#   Step 6:  Data Requirements
#   Step 7:  Integration Requirements
#   Step 8:  Out of Scope
#   Step 9:  Constraints and Assumptions
#   Step 10: Success Criteria
#   Step 11: Generate Output
#   Step 12: Adversarial Review
#   Step 13: Incorporate Adversarial Findings
#
# pm subagent contract:
#   PRD authoring delegated to pm subagent (Derek) — no inline persona.
#   Subagent file: agents/pm.md
#
# Output path: docs/planning-artifacts/prd.md
