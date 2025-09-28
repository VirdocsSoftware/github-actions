#!/usr/bin/env node

const fs = require('fs');

/**
 * Filters out specified files from a git diff
 * Usage: node filter_diff.js <diff_file> <ignore_files_comma_separated>
 */

function filterDiff(diffContent, ignoreFiles) {
  if (!ignoreFiles || ignoreFiles.trim() === '') {
    return diffContent;
  }

  const filesToIgnore = ignoreFiles.split(',').map(f => f.trim()).filter(f => f.length > 0);
  if (filesToIgnore.length === 0) {
    return diffContent;
  }

  const lines = diffContent.split('\n');
  const filteredLines = [];
  let currentFile = null;
  let skipCurrentFile = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    // Check if this is a file header line (starts with diff --git)
    if (line.startsWith('diff --git ')) {
      // Extract the file path from the diff header
      // Format: diff --git a/path/to/file b/path/to/file
      const match = line.match(/diff --git a\/(.+?) b\/(.+?)$/);
      if (match) {
        currentFile = match[1]; // Use the 'a/' path
        
        // Check if this file should be ignored
        skipCurrentFile = filesToIgnore.some(ignoreFile => {
          // Support both exact matches and basename matches
          return currentFile === ignoreFile || currentFile.endsWith('/' + ignoreFile) || currentFile === ignoreFile;
        });
        
        if (skipCurrentFile) {
          // Skip all lines until the next file or end of diff
          while (i + 1 < lines.length && !lines[i + 1].startsWith('diff --git ')) {
            i++;
          }
          continue;
        }
      }
    }
    
    // If we're not skipping the current file, include the line
    if (!skipCurrentFile) {
      filteredLines.push(line);
    }
  }

  return filteredLines.join('\n');
}

// Main execution
if (require.main === module) {
  const [, , diffFile, ignoreFiles] = process.argv;
  
  if (!diffFile) {
    console.error('Usage: filter_diff.js <diff_file> <ignore_files_comma_separated>');
    process.exit(1);
  }

  if (!fs.existsSync(diffFile)) {
    console.error(`Error: Diff file not found at ${diffFile}`);
    process.exit(1);
  }

  try {
    const diffContent = fs.readFileSync(diffFile, 'utf8');
    const filteredDiff = filterDiff(diffContent, ignoreFiles || '');
    
    // Write filtered diff back to the same file
    fs.writeFileSync(diffFile, filteredDiff, 'utf8');
    
    // Output statistics
    const originalLines = diffContent.split('\n').length;
    const filteredLines = filteredDiff.split('\n').length;
    const removedLines = originalLines - filteredLines;
    
    console.error(`Filtered diff: removed ${removedLines} lines (${originalLines} -> ${filteredLines})`);
    if (ignoreFiles) {
      console.error(`Ignored files: ${ignoreFiles}`);
    }
  } catch (error) {
    console.error(`Error filtering diff: ${error.message}`);
    process.exit(1);
  }
}

module.exports = { filterDiff };
