# Importable branch rules

These JSON files document the repository protections used for Pep. They are
intended to be imported or recreated in GitHub **Settings > Rules > Rulesets**;
committing a JSON file does not activate a GitHub ruleset by itself.

The default branch requires changes to arrive through a pull request, prevents
branch deletion and force-pushes, and allows squash merges. All branches also
require signed commits. Adjust the bypass actors and enforcement level for your
team before enabling these rules on a different repository.
