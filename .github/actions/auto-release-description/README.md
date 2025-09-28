# Auto PR Description Generator

A reusable GitHub Action that automatically generates pull request descriptions using AI (Google Gemini) based on the git diff of changes.

## Features

- 🤖 **AI-Powered**: Uses Google Gemini to analyze code changes and generate meaningful descriptions
- 🎯 **Smart Formatting**: Generates structured descriptions with Description, Changes, and Verification sections
- 🖼️ **Image Preservation**: Maintains existing images at the top of PR descriptions
- 🎫 **JIRA Integration**: Automatically extracts JIRA ticket IDs and adds ticket links
- 🚫 **Smart Filtering**: Automatically ignores large files like package-lock.json to prevent token size issues
- ⚡ **Fast & Lightweight**: Minimal dependencies and quick execution

## Usage

### Basic Usage

```yaml
- name: Generate PR Description
  uses: ./.github/actions/auto-pr-description
  with:
    gemini-api-key: ${{ secrets.GEMINI_API_KEY }}
    github-token: ${{ secrets.GITHUB_TOKEN }}
    pr-number: ${{ github.event.pull_request.number }}
```

### Complete Workflow Example

```yaml
name: Auto PR Description
on:
  pull_request:
    types: [labeled]

jobs:
  update-pr-description:
    name: Update PR Description
    runs-on: ubuntu-latest
    if: |
      github.event_name == 'pull_request' &&
      github.base_ref == 'main' &&
      (github.event.pull_request.draft == false || github.event.action == 'labeled') &&
      (contains(github.event.pull_request.labels.*.name, 'auto-pr-description') || 
       contains(github.event.pull_request.labels.*.name, 'test'))
    permissions:
      pull-requests: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate PR Description
        uses: ./.github/actions/auto-pr-description
        with:
          gemini-api-key: ${{ secrets.GEMINI_API_KEY }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
          pr-number: ${{ github.event.pull_request.number }}
          jira-ticket-url-prefix: 'https://yourcompany.atlassian.net/browse/'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `gemini-api-key` | The API key for the Gemini API | ✅ | - |
| `github-token` | GitHub token for PR operations | ✅ | - |
| `pr-number` | Pull request number | ✅ | - |
| `jira-ticket-url-prefix` | JIRA ticket URL prefix | ❌ | `https://virdocs.atlassian.net/browse/` |
| `ignore-files` | Comma-separated list of files to ignore in diff | ❌ | `package-lock.json,yarn.lock,pnpm-lock.yaml,composer.lock,Gemfile.lock,poetry.lock,Pipfile.lock` |

## Outputs

| Output | Description |
|--------|-------------|
| `description` | The generated PR description |
| `updated` | Whether the PR description was updated |

## Generated Description Format

The action generates PR descriptions in this structured format:

```markdown
## Description
A concise summary of what the changes accomplish.

## Changes
- [ ] Specific change or feature added
- [ ] Another modification made
- [ ] Bug fix or improvement

## Verification
- [ ] Test that should be performed
- [ ] Verification step to confirm functionality
- [ ] Additional checks recommended

## Ticket
https://yourcompany.atlassian.net/browse/TICKET-123
```

## JIRA Integration

The action automatically detects JIRA ticket IDs from:
1. **PR Title**: Extracts patterns like `CORE-1234`, `PAR-567`, etc.
2. **Branch Name**: Falls back to branch name if not found in title

Example branch names that work:
- `CORE-1234-feature-description`
- `PAR-567-bug-fix`
- `feature/CORE-1234-new-feature`

## Prerequisites

### Required Secrets

1. **GEMINI_API_KEY**: Get your API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. **GITHUB_TOKEN**: Automatically provided by GitHub Actions

### Required Permissions

The workflow must have these permissions:
```yaml
permissions:
  pull-requests: write
  contents: read
```

## Trigger Patterns

### Label-Based Triggering
Add these labels to trigger the action:
- `auto-pr-description`: Specific label for PR description generation
- `test`: Dual-purpose label that can trigger both testing and description generation

### Draft Mode Handling
- **Draft PRs**: Action doesn't run automatically to save CI resources
- **Label Override**: Adding trigger labels to draft PRs will run the action
- **Ready for Review**: Converting draft to ready automatically triggers the action

## Error Handling

The action handles various error scenarios:
- Missing or invalid Gemini API key
- API rate limits and timeouts
- Large diffs that exceed API limits
- Network connectivity issues
- Invalid PR numbers

## Customization

### Custom JIRA URL
```yaml
- uses: ./.github/actions/auto-pr-description
  with:
    jira-ticket-url-prefix: 'https://mycompany.atlassian.net/browse/'
    # ... other inputs
```

### Custom File Filtering
By default, the action ignores common lock files that can be very large and don't provide meaningful context for PR descriptions. You can customize which files to ignore:

```yaml
- uses: ./.github/actions/auto-pr-description
  with:
    ignore-files: 'package-lock.json,yarn.lock,dist/bundle.js,build/'
    # ... other inputs
```

**Default ignored files:**
- `package-lock.json` (npm)
- `yarn.lock` (Yarn)
- `pnpm-lock.yaml` (pnpm)
- `composer.lock` (PHP Composer)
- `Gemfile.lock` (Ruby Bundler)
- `poetry.lock` (Python Poetry)
- `Pipfile.lock` (Python Pipenv)

**Why filter files?**
Large files like lock files can cause the AI API to hit token limits, resulting in failed PR description generation. By filtering these files, the action focuses on meaningful code changes while staying within API limits.

### Using Outputs
```yaml
- name: Generate PR Description
  id: pr-desc
  uses: ./.github/actions/auto-pr-description
  with:
    # ... inputs

- name: Use generated description
  run: |
    echo "Generated description: ${{ steps.pr-desc.outputs.description }}"
    echo "Was updated: ${{ steps.pr-desc.outputs.updated }}"
```

## Troubleshooting

### Common Issues

1. **Missing API Key**: Ensure `GEMINI_API_KEY` is set in repository secrets
2. **Permission Denied**: Check that workflow has `pull-requests: write` permission
3. **Large Diffs**: Very large changes might exceed API limits - use `ignore-files` to filter out large files or consider smaller PRs
4. **Rate Limits**: Gemini API has rate limits - add delays between calls if needed
5. **Invalid PR Number**: Ensure the PR number is valid and accessible

### Debug Mode

Enable debug logging by setting:
```yaml
env:
  ACTIONS_STEP_DEBUG: true
```

## License

MIT License - see LICENSE file for details.
