#!/usr/bin/env node

const { filterDiff } = require('./filter_diff.js');

// Test data
const sampleDiff = `diff --git a/src/app.js b/src/app.js
index 1234567..abcdefg 100644
--- a/src/app.js
+++ b/src/app.js
@@ -1,3 +1,4 @@
 const express = require('express');
+const cors = require('cors');
 const app = express();
 
diff --git a/package-lock.json b/package-lock.json
index 9876543..fedcba9 100644
--- a/package-lock.json
+++ b/package-lock.json
@@ -1,1000 +1,1001 @@
 {
   "name": "test-app",
   "version": "1.0.0",
+  "lockfileVersion": 2,
   "requires": true,
   "packages": {
     "": {
       "name": "test-app",
       "version": "1.0.0"
     }
   }
 }

diff --git a/README.md b/README.md
index 2468135..1357924 100644
--- a/README.md
+++ b/README.md
@@ -1,2 +1,3 @@
 # Test App
 This is a test application.
+Updated documentation.
`;

console.log('Testing diff filtering...\n');

// Test 1: Filter package-lock.json
console.log('Test 1: Filter package-lock.json');
const filtered1 = filterDiff(sampleDiff, 'package-lock.json');
console.log('Original lines:', sampleDiff.split('\n').length);
console.log('Filtered lines:', filtered1.split('\n').length);
console.log('Contains package-lock.json:', filtered1.includes('package-lock.json'));
console.log('Contains src/app.js:', filtered1.includes('src/app.js'));
console.log('Contains README.md:', filtered1.includes('README.md'));
console.log('');

// Test 2: Filter multiple files
console.log('Test 2: Filter multiple files');
const filtered2 = filterDiff(sampleDiff, 'package-lock.json,README.md');
console.log('Original lines:', sampleDiff.split('\n').length);
console.log('Filtered lines:', filtered2.split('\n').length);
console.log('Contains package-lock.json:', filtered2.includes('package-lock.json'));
console.log('Contains README.md:', filtered2.includes('README.md'));
console.log('Contains src/app.js:', filtered2.includes('src/app.js'));
console.log('');

// Test 3: No filtering
console.log('Test 3: No filtering');
const filtered3 = filterDiff(sampleDiff, '');
console.log('Original lines:', sampleDiff.split('\n').length);
console.log('Filtered lines:', filtered3.split('\n').length);
console.log('Same content:', sampleDiff === filtered3);
console.log('');

// Test 4: Filter non-existent file
console.log('Test 4: Filter non-existent file');
const filtered4 = filterDiff(sampleDiff, 'non-existent.txt');
console.log('Original lines:', sampleDiff.split('\n').length);
console.log('Filtered lines:', filtered4.split('\n').length);
console.log('Same content:', sampleDiff === filtered4);

console.log('\nAll tests completed!');
