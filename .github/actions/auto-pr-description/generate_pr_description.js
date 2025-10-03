#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Configuration constants
const MAX_TOKENS_PER_REQUEST = 100000; // Conservative limit for Gemini 2.5 Flash
const CHARS_PER_TOKEN = 4; // Rough estimation
const MAX_CHARS_PER_CHUNK = MAX_TOKENS_PER_REQUEST * CHARS_PER_TOKEN;
const MAX_CHUNKS = 10; // Limit to prevent excessive API calls

/**
 * Estimate token count for text (rough approximation)
 */
function estimateTokens(text) {
  return Math.ceil(text.length / CHARS_PER_TOKEN);
}

/**
 * Split diff into chunks by file boundaries
 */
function chunkDiffByFiles(diffContent) {
  const fileChunks = [];
  const lines = diffContent.split('\n');
  let currentChunk = '';
  let currentFile = '';
  
  for (const line of lines) {
    // Check if this is a new file header
    if (line.startsWith('diff --git') || line.startsWith('+++') || line.startsWith('---')) {
      // If we have content and it's getting large, save current chunk
      if (currentChunk && estimateTokens(currentChunk) > MAX_CHARS_PER_CHUNK / 2) {
        fileChunks.push({
          content: currentChunk.trim(),
          file: currentFile,
          type: 'file-chunk'
        });
        currentChunk = '';
      }
      
      // Start new chunk
      currentChunk = line + '\n';
      
      // Extract filename for reference
      if (line.startsWith('+++')) {
        currentFile = line.replace('+++ b/', '').replace('+++ a/', '');
      }
    } else {
      currentChunk += line + '\n';
    }
  }
  
  // Add the last chunk
  if (currentChunk.trim()) {
    fileChunks.push({
      content: currentChunk.trim(),
      file: currentFile,
      type: 'file-chunk'
    });
  }
  
  return fileChunks;
}

/**
 * Create a summary prompt for extremely large diffs
 */
function createSummaryPrompt(diffContent) {
  return `Analyze this git diff and provide a high-level summary. Focus on:
1. What types of files were changed (e.g., source code, tests, config, docs)
2. The overall scope of changes (e.g., new feature, bug fix, refactor)
3. Any major architectural changes or new dependencies

Keep the summary to 2-3 sentences maximum.

Git diff:
${diffContent}`;
}

/**
 * Create the main PR description prompt
 */
function createPRPrompt(diffContent) {
  return `Write a concise pull request description based on the git diff. Use this exact format:

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

Keep it concise and focused on the most important changes.

Here is the git diff:

${diffContent}`;
}

/**
 * Call Gemini API with the given prompt
 */
async function callGeminiAPI(prompt, apiKey) {
  const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{
        parts: [{
          text: prompt
        }]
      }],
      generationConfig: {
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 8192,
      }
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Gemini API request failed with status ${response.status}: ${errorText}`);
  }

  const json = await response.json();
  
  if (!json.candidates || !json.candidates[0]) {
    throw new Error('Invalid response from Gemini API');
  }

  if (!json.candidates[0].content || !json.candidates[0].content.parts || !json.candidates[0].content.parts[0] || !json.candidates[0].content.parts[0].text) {
    throw new Error('Invalid response structure from Gemini API - missing content');
  }

  return json.candidates[0].content.parts[0].text;
}

/**
 * Process diff chunks and combine results
 */
async function processChunks(chunks, apiKey) {
  if (chunks.length === 1) {
    // Single chunk, process normally
    return await callGeminiAPI(createPRPrompt(chunks[0].content), apiKey);
  }

  // Multiple chunks - process each and combine
  const chunkResults = [];
  
  for (let i = 0; i < Math.min(chunks.length, MAX_CHUNKS); i++) {
    const chunk = chunks[i];
    console.error(`Processing chunk ${i + 1}/${Math.min(chunks.length, MAX_CHUNKS)} (${chunk.file || 'unknown file'})`);
    
    try {
      const result = await callGeminiAPI(createPRPrompt(chunk.content), apiKey);
      chunkResults.push({
        file: chunk.file,
        result: result
      });
    } catch (error) {
      console.error(`Warning: Failed to process chunk ${i + 1}: ${error.message}`);
      // Continue with other chunks
    }
  }

  if (chunkResults.length === 0) {
    throw new Error('Failed to process any chunks');
  }

  // Combine results from multiple chunks
  const combinedPrompt = `Combine these pull request descriptions into a single, coherent PR description. Use the same format:

${chunkResults.map((chunk, index) => `## Chunk ${index + 1} (${chunk.file}):
${chunk.result}`).join('\n\n')}

Create a unified description that captures the overall changes across all files.`;

  return await callGeminiAPI(combinedPrompt, apiKey);
}

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

  const diffContent = fs.readFileSync(diffFile, 'utf8');
  const estimatedTokens = estimateTokens(diffContent);
  
  console.error(`Diff size: ${diffContent.length} characters (~${estimatedTokens} tokens)`);

  try {
    let result;

    if (estimatedTokens > MAX_TOKENS_PER_REQUEST) {
      console.error('Large diff detected, using chunking strategy...');
      
      // For extremely large diffs, first try to summarize
      if (estimatedTokens > MAX_TOKENS_PER_REQUEST * 5) {
        console.error('Extremely large diff detected, using summary approach...');
        const summaryPrompt = createSummaryPrompt(diffContent);
        result = await callGeminiAPI(summaryPrompt, apiKey);
        
        // Create a simplified PR description based on the summary
        const prPrompt = `Based on this summary of changes, create a pull request description using this format:

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

Summary: ${result}`;
        
        result = await callGeminiAPI(prPrompt, apiKey);
      } else {
        // Chunk the diff and process
        const chunks = chunkDiffByFiles(diffContent);
        console.error(`Split diff into ${chunks.length} chunks`);
        
        if (chunks.length > MAX_CHUNKS) {
          console.error(`Warning: Too many chunks (${chunks.length}), processing first ${MAX_CHUNKS} chunks only`);
        }
        
        result = await processChunks(chunks, apiKey);
      }
    } else {
      // Small diff, process normally
      result = await callGeminiAPI(createPRPrompt(diffContent), apiKey);
    }

    process.stdout.write(result);
  } catch (error) {
    console.error(`Error: Failed to generate pull request description: ${error.message}`);
    process.exit(1);
  }
})();
