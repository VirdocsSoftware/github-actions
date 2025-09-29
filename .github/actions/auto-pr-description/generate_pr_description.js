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
  const promptTemplate = `Write a concise pull request description based on the git diff. Use this exact format:

## Description
Brief summary of changes (1-2 sentences max).

## Changes
- [ ] Key change 1
- [ ] Key change 2
- [ ] Key change 3 (max 5 items)

## Verification
- [ ] Test step 1
- [ ] Test step 2
- [ ] Test step 3 (max 3 items)

Keep it concise and focused on the most important changes.`;

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
          maxOutputTokens: 1024,
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
    
    if (!json.candidates || !json.candidates[0]) {
      console.error('Error: Invalid response from Gemini API');
      console.error(JSON.stringify(json, null, 2));
      process.exit(1);
    }

    // Check if response was truncated due to max tokens
    if (json.candidates[0].finishReason === 'MAX_TOKENS') {
      console.error('Warning: Response was truncated due to token limit. Consider reducing diff size or using more specific ignore-files.');
      // Continue processing the partial response
    }

    if (!json.candidates[0].content) {
      console.error('Error: No content in API response');
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
