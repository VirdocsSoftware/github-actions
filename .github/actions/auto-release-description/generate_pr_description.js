#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

(async () => {
  const [, , diffFile] = process.argv;
  if (!diffFile) {
    console.error('Usage: generate_pr_description.js <diff_file>');
    process.exit(1);
  }

  if (!fs.existsSync(diffFile)) {
    console.error(`Error: Diff file not found at ${diffFile}`);
    process.exit(1);
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.error('Error: GEMINI_API_KEY environment variable is required');
    process.exit(1);
  }

  // Create prompt for PR description generation
  const promptTemplate = `You are an expert programmer who is tasked with writing a pull request description.
You will be given the git diff of the changes and you must write a markdown pull request description.
Do not include the git diff in the pull request description. Do not include any other text in the pull request description.
The pull request description should follow the following format:

## Description
A short description of the changes.

## Changes
- [ ] Change 1
- [ ] Change 2

## Verification
- [ ] Verification step 1
- [ ] Verification step 2
`;

  const diffContent = fs.readFileSync(diffFile, 'utf8');
  const combinedPrompt = `${promptTemplate}\n\nHere is the git diff:\n\n${diffContent}`;

  try {
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{
          parts: [{
            text: combinedPrompt
          }]
        }],
        generationConfig: {
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 2048,
        }
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`Error: Gemini API request failed with status ${response.status}`);
      console.error(`Response: ${errorText}`);
      process.exit(1);
    }

    const json = await response.json();
    
    if (!json.candidates || !json.candidates[0] || !json.candidates[0].content) {
      console.error('Error: Invalid response from Gemini API');
      console.error(JSON.stringify(json, null, 2));
      process.exit(1);
    }

    if (!json.candidates[0].content.parts || !json.candidates[0].content.parts[0] || !json.candidates[0].content.parts[0].text) {
      console.error('Error: Invalid response structure from Gemini API - missing parts or text');
      console.error(JSON.stringify(json, null, 2));
      process.exit(1);
    }

    const result = json.candidates[0].content.parts[0].text;
    process.stdout.write(result);
  } catch (error) {
    console.error(`Error: Failed to generate pull request description: ${error.message}`);
    process.exit(1);
  }
})();
