#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Configuration constants
const MAX_TOKENS_PER_REQUEST = 80000; // Conservative limit for Gemini 2.5 Flash
const CHARS_PER_TOKEN = 4; // Rough estimation
//const MAX_CHARS_PER_CHUNK = MAX_TOKENS_PER_REQUEST * CHARS_PER_TOKEN;
const MAX_CHUNKS = 5; // Limit to prevent excessive API calls

/**
 * Estimate token count for text (rough approximation)
 */
function estimateTokens(text) {
  return Math.ceil(text.length / CHARS_PER_TOKEN);
}


function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}


function splitStringByTokens(str, maxTokens) {
  console.error('splitStringByTokens');
  const words = str.split(' ');
  const result = [];
  let currentLine = '';

  for (const word of words) {
    if (estimateTokens(currentLine + word) <= maxTokens) {
      currentLine += (currentLine ? ' ' : '') + word;
    } else {
      if (currentLine) result.push(currentLine);
      currentLine = word;
    }
  }

  if (currentLine) result.push(currentLine);

  return result;
}


/**
 * Split diff into chunks by file boundaries
 */
function chunkDiffByFiles(diffContent) {
  console.error('chunkDiffByFiles');
  const fileChunks = [];
  const lines = diffContent.split('\n');
  let currentChunk = '';
  let currentFile = '';
  let currentChunkTokenCount = 0;
  const PROMPT_OVERHEAD = 2000; // Reserve tokens for prompt overhead
  const MAX_CHUNK_TOKENS = MAX_TOKENS_PER_REQUEST - PROMPT_OVERHEAD;
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const lineTokens = estimateTokens(line);
    const isNewFile = line.startsWith('diff --git');
    const isFileHeader = line.startsWith('+++') || line.startsWith('---');
    
    // Check if we need to split current chunk before adding this line
    if (currentChunk && (currentChunkTokenCount + lineTokens) > MAX_CHUNK_TOKENS) {
      // Current chunk is getting too large, save it
      fileChunks.push({
        content: currentChunk.trim(),
        file: currentFile,
        type: 'file-chunk'
      });
      console.error(`Chunk ${fileChunks.length} saved: ${currentChunkTokenCount} tokens for ${currentFile || 'unknown'}`);
      currentChunk = '';
      currentChunkTokenCount = 0;
    }
    
    // Handle new file boundaries
    if (isNewFile) {
      // Extract filename from next lines
      // Look ahead for +++ line
      for (let j = i + 1; j < Math.min(i + 10, lines.length); j++) {
        if (lines[j].startsWith('+++')) {
          currentFile = lines[j].replace('+++ b/', '').replace('+++ a/', '');
          break;
        }
      }
    }
    
    // Add line to current chunk
    currentChunk += line + '\n';
    currentChunkTokenCount += lineTokens;
    
    // If a single line is too large, split it
    if (lineTokens > MAX_CHUNK_TOKENS && currentChunk.length > 100) {
      // Remove the line from current chunk
      currentChunk = currentChunk.substring(0, currentChunk.length - line.length - 1);
      currentChunkTokenCount -= lineTokens;
      
      // Split the large line
      const splitChunks = splitStringByTokens(line, MAX_CHUNK_TOKENS);
      for (let j = 0; j < splitChunks.length; j++) {
        if (j > 0) {
          // Save previous chunk if it has content
          if (currentChunk.trim()) {
            fileChunks.push({
              content: currentChunk.trim(),
              file: currentFile,
              type: 'file-chunk'
            });
            currentChunk = '';
            currentChunkTokenCount = 0;
          }
        }
        currentChunk = splitChunks[j] + '\n';
        currentChunkTokenCount = estimateTokens(currentChunk);
      }
    }
  }
  
  // Add the last chunk
  if (currentChunk.trim()) {
    fileChunks.push({
      content: currentChunk.trim(),
      file: currentFile,
      type: 'file-chunk'
    });
    console.error(`Final chunk ${fileChunks.length} saved: ${currentChunkTokenCount} tokens for ${currentFile || 'unknown'}`);
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
  return `Write a release note summary with the following sections:

  ## Infrastructure Changes
  Highlight changes to AWS resources, IaC (CloudFormation/SAM templates), Lambda functions, databases, and deployment configurations.

  ## Security Concerns
  Identify any security-related changes, authentication/authorization updates, data access modifications, or potential vulnerabilities.

  ## Performance Implications
  Assess any changes that could impact system performance, database queries, API response times, or resource consumption.

  ## New Features
  Describe new functionality, enhancements, or capabilities being introduced.

  ## Student Access Risk Analysis
  Evaluate the risk that these changes could cause students to lose access to their course materials. Assess changes to:

  - Term ID handling and relationships
  - Adoption, section, product, or term product relationships
  - Data export or deduplication logic
  - Database schema affecting terms, sections, or student access
  - Section Channel Offer (SCO) activation/deactivation logic
  - Query logic for student materials or permissions

  For each risk identified, provide: Risk Level (NONE/LOW/MEDIUM/HIGH/CRITICAL), specific changes, risk description, and recommended verification steps.

  If no student access risks are detected, state: "Risk Level: NONE - No changes affect student material access."

  Print only the report and ask no questions.

${diffContent}`;
}

/**
 * Call Gemini API with the given prompt (with retry logic for rate limits)
 */
async function callGeminiAPI(prompt, apiKey, retryCount = 0) {
  const maxRetries = 3;
  const baseDelay = 1000; // 1 second base delay
  
  console.error(`Sending prompt with an estimated ${estimateTokens(prompt)} tokens`);
  
  try {
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`, {
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

    // Handle rate limiting (429) with exponential backoff
    if (response.status === 429 && retryCount < maxRetries) {
      const delay = baseDelay * Math.pow(2, retryCount); // Exponential backoff: 1s, 2s, 4s
      console.error(`Rate limit hit, retrying in ${delay}ms (attempt ${retryCount + 1}/${maxRetries})`);
      await sleep(delay);
      return await callGeminiAPI(prompt, apiKey, retryCount + 1);
    }

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
  } catch (error) {
    // If it's a network error and we have retries left, retry with exponential backoff
    if (retryCount < maxRetries && (error.message.includes('fetch') || error.message.includes('network'))) {
      const delay = baseDelay * Math.pow(2, retryCount);
      console.error(`Network error, retrying in ${delay}ms (attempt ${retryCount + 1}/${maxRetries}): ${error.message}`);
      await sleep(delay);
      return await callGeminiAPI(prompt, apiKey, retryCount + 1);
    }
    throw error;
  }
}

/**
 * Process diff chunks and combine results
 */
async function processChunks(chunks, apiKey) {
  console.error('processchunks');
  if (chunks.length === 1) {
    // Single chunk, process normally
    return await callGeminiAPI(createPRPrompt(chunks[0].content), apiKey);
  }

  // Multiple chunks - process each and combine
  const chunkResults = [];
  const CHUNK_DELAY = 500; // 500ms delay between chunks (reduced from 5s)
  
  for (let i = 0; i < Math.min(chunks.length, MAX_CHUNKS); i++) {
    const chunk = chunks[i];
    if (i > 0) {
      // Small delay between chunks to avoid rate limits (reduced from 5s to 500ms)
      await sleep(CHUNK_DELAY);
    }
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
  
  // Small delay before combining (reduced from 5s to 500ms)
  await sleep(CHUNK_DELAY);
  
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
      
      const chunks = chunkDiffByFiles(diffContent);
      console.error(`Split diff into ${chunks.length} chunks`);
      if (chunks.length > MAX_CHUNKS) {
        console.error(`Warning: Too many chunks (${chunks.length}), processing first ${MAX_CHUNKS} chunks only`);
      }
      result = await processChunks(chunks, apiKey);
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
