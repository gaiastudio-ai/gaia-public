# Test Artifact — Relative Path References

This artifact uses relative paths:

- Script: `../scripts/memory-loader.sh`
- Skill: `./skills/gaia-val-validate-plan/SKILL.md`
- Parent: `../../plugins/gaia/scripts/checkpoint.sh`

The validator should normalize these paths relative to the project root before scanning.
