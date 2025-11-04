#!/usr/bin/env node

const fs = require('fs');

/**
 * Inserts a release description into an existing PR body using HTML comment tags.
 * This preserves all existing PR body content while allowing replacement of the
 * auto-generated section.
 * 
 * Usage: node insert_release_description.js <body_file> <description_file>
 */

const [, , bodyPath, descriptionPath] = process.argv;

if (!bodyPath || !descriptionPath) {
  console.error('Usage: insert_release_description.js <body_file> <description_file>');
  process.exit(1);
}

const START_TAG = '<!-- start auto generated release description -->';
const END_TAG = '<!-- end auto generated release description -->';

if (!fs.existsSync(bodyPath)) {
  console.error(`Error: Body file not found at ${bodyPath}`);
  process.exit(1);
}

if (!fs.existsSync(descriptionPath)) {
  console.error(`Error: Description file not found at ${descriptionPath}`);
  process.exit(1);
}

const body = fs.readFileSync(bodyPath, 'utf8');
const description = fs.readFileSync(descriptionPath, 'utf8').trim();

const block = `${START_TAG}\n${description}\n${END_TAG}`;

let result;
const startIndex = body.indexOf(START_TAG);

if (startIndex === -1) {
  // No existing tags - append the description block
  const trimmed = body.trimEnd();
  const prefix = trimmed.length > 0 ? trimmed + '\n\n' : '';
  result = `${prefix}${block}\n`;
} else {
  // Tags exist - replace content between tags
  const endIndex = body.indexOf(END_TAG, startIndex + START_TAG.length);
  
  if (endIndex === -1) {
    // Start tag exists but no end tag - replace from start tag to end
    result = body.slice(0, startIndex) + block + '\n';
  } else {
    // Both tags exist - replace content between them
    result = body.slice(0, startIndex) + block + body.slice(endIndex + END_TAG.length);
    if (!result.endsWith('\n')) {
      result += '\n';
    }
  }
}

process.stdout.write(result);

