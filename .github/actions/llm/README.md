# Gemini Text Generation GitHub Action

This GitHub Action sends a prompt to Google Gemini and retrieves the text response.

## Inputs

- `gemini-api-key`: **Required**. The API key for the Gemini API.
- `prompt`: **Required**. The prompt to send to Gemini.

## Outputs

- `response`: The text response from Gemini.

## Example Usage

```yaml
name: Generate Text with Gemini
on: [push]

jobs:
  generate-text:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v2
        with:
          fetch-depth: 0
      - name: Generate text with Gemini
        id: generate_text
        uses: virdocsSoftware/github-actions/.github/actions/llm@main
        with:
          gemini-api-key: ${{ secrets.GEMINI_API_KEY }}
          prompt: 'Your prompt here'

      - name: Display response
        run: echo "${{ steps.generate_text.outputs.response }}"