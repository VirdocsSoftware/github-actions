# Tag Jira Release

A GitHub Action to tag Jira releases.

## Author

Ansel Robateau

## Inputs

| Name           | Description                                | Required | Default                |
|----------------|--------------------------------------------|----------|------------------------|
| `target-branch`| The target branch                          | false    | `origin/main`          |
| `jira-token`   | The Jira API token                         | true     |                        |
| `jira-email`   | The Jira email                             | true     |                        |
| `jira-domain`  | The Jira domain                            | true     |                        |
| `description`  | The description of the release             | false    | `Next awesome release` |
| `dry-run`      | Whether to run in dry-run mode             | false    | `false`                |


## Usage

```yaml
name: Tag Jira Release
on: [push]

jobs:
  tag-jira-release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Tag Jira Release
        uses: VirdocsSoftware/github-actions/.github/actions/tag-jira-release@main
        with:
          target-branch: 'origin/main'
          jira-token: ${{ secrets.JIRA_TOKEN }}
          jira-email: ${{ secrets.JIRA_EMAIL }}
          jira-domain: ${{ secrets.JIRA_DOMAIN }}
          description: 'Next awesome release'
          dry-run: 'false'
