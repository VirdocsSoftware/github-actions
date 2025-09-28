const fs = require('fs');
const path = require('path');

/**
 * Compares two semantic version strings and returns the higher version
 * @param {string} version1 - First version string
 * @param {string} version2 - Second version string
 * @returns {string} The higher version
 */
function getHigherVersion(version1, version2) {
  // Remove any prefix characters like ^, ~, etc.
  const cleanVersion1 = version1.replace(/^[\^~]/, '');
  const cleanVersion2 = version2.replace(/^[\^~]/, '');
  
  // Get the prefix from the first version to preserve it
  const prefix = version1.match(/^[\^~]/)?.[0] || '';
  
  // Simple version comparison (for basic cases)
  const v1Parts = cleanVersion1.split('.').map(Number);
  const v2Parts = cleanVersion2.split('.').map(Number);
  
  for (let i = 0; i < Math.max(v1Parts.length, v2Parts.length); i++) {
    const v1 = v1Parts[i] || 0;
    const v2 = v2Parts[i] || 0;
    
    if (v1 > v2) {
      return version1;
    } else if (v2 > v1) {
      return prefix + cleanVersion2;
    }
  }
  
  // If versions are equal, return the first one
  return version1;
}

/**
 * Updates a package.json file with the highest version for specified dependencies
 * @param {string} packageJsonPath - Path to the package.json file
 * @param {Object} updates - Object mapping dependency names to their highest versions
 * @param {string} layerPackageJsonPath - Path to the layer package.json for comparison
 * @returns {Object} Summary of changes made
 */
function updatePackageJson(packageJsonPath, updates, layerPackageJsonPath) {
  const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
  const layerPackageJson = JSON.parse(fs.readFileSync(layerPackageJsonPath, 'utf8'));
  
  const changes = {
    updated: [],
    errors: []
  };
  
  // Get all dependency sections
  const dependencySections = ['dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies'];
  
  for (const [depName, highestVersion] of Object.entries(updates)) {
    let updated = false;
    
    for (const section of dependencySections) {
      if (packageJson[section] && packageJson[section][depName]) {
        const currentVersion = packageJson[section][depName];
        
        if (currentVersion !== highestVersion) {
          packageJson[section][depName] = highestVersion;
          changes.updated.push({
            dependency: depName,
            section,
            oldVersion: currentVersion,
            newVersion: highestVersion,
            file: packageJsonPath
          });
          updated = true;
          break; // Only update in the first section where it's found
        }
      }
    }
    
    if (!updated) {
      changes.errors.push({
        dependency: depName,
        error: `Dependency ${depName} not found in package.json`,
        file: packageJsonPath
      });
    }
  }
  
  // Write the updated package.json back to file
  if (changes.updated.length > 0) {
    fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2) + '\n');
  }
  
  return changes;
}

/**
 * Processes the JSON output from layer dependency analysis and updates package.json files
 * @param {Object} analysisData - JSON output from layer dependency analysis
 * @param {string} layerPackageJsonPath - Path to the layer package.json file
 * @param {string} domainsPath - Path to the domains directory
 * @returns {Object} Summary of all changes made
 */
function processAnalysisData(analysisData, layerPackageJsonPath, domainsPath) {
  const summary = {
    totalFilesUpdated: 0,
    totalDependenciesUpdated: 0,
    errors: [],
    changes: []
  };
  
  // Group mismatches by dependency to find the highest version for each
  const dependencyVersions = new Map();
  
  for (const report of analysisData.reports) {
    for (const mismatch of report.mismatches) {
      const { dependency, version1, version2 } = mismatch;
      
      if (!dependencyVersions.has(dependency)) {
        dependencyVersions.set(dependency, version1);
      }
      
      const currentHighest = dependencyVersions.get(dependency);
      const newHighest = getHigherVersion(currentHighest, version2);
      dependencyVersions.set(dependency, newHighest);
    }
  }
  
  // Update each package.json file that has mismatches
  for (const report of analysisData.reports) {
    if (report.hasMismatches) {
      const packageJsonPath = path.join(domainsPath, report.project, 'package.json');
      
      // Create updates object for this specific file
      const updates = {};
      for (const mismatch of report.mismatches) {
        const highestVersion = dependencyVersions.get(mismatch.dependency);
        if (highestVersion) {
          updates[mismatch.dependency] = highestVersion;
        }
      }
      
      try {
        const changes = updatePackageJson(packageJsonPath, updates, layerPackageJsonPath);
        summary.changes.push(...changes.updated);
        summary.errors.push(...changes.errors);
        
        if (changes.updated.length > 0) {
          summary.totalFilesUpdated++;
          summary.totalDependenciesUpdated += changes.updated.length;
        }
      } catch (error) {
        summary.errors.push({
          file: packageJsonPath,
          error: error.message
        });
      }
    }
  }
  
  return summary;
}

function main() {
  if (process.argv.length < 4) {
    console.error('Usage: node update_package_versions.js <analysis-json-file> <layer-package-json> <domains-path>');
    console.error('');
    console.error('Example:');
    console.error('  node layer_dependency_analysis.js --json layer-package.json domains.json > analysis.json');
    console.error('  node update_package_versions.js analysis.json layer-package.json ./domains');
    process.exit(1);
  }
  
  const analysisJsonFile = process.argv[2];
  const layerPackageJsonPath = process.argv[3];
  const domainsPath = process.argv[4];
  
  try {
    // Read the analysis JSON data
    const analysisData = JSON.parse(fs.readFileSync(analysisJsonFile, 'utf8'));
    
    console.log('Processing layer dependency analysis data...');
    console.log(`Analysis timestamp: ${analysisData.timestamp}`);
    console.log(`Total domains analyzed: ${analysisData.totalDomainsAnalyzed}`);
    console.log(`Domains with mismatches: ${analysisData.domainsWithMismatches}`);
    console.log('');
    
    // Process the data and update package.json files
    const summary = processAnalysisData(analysisData, layerPackageJsonPath, domainsPath);
    
    // Output summary
    console.log('=== Update Summary ===');
    console.log(`Files updated: ${summary.totalFilesUpdated}`);
    console.log(`Dependencies updated: ${summary.totalDependenciesUpdated}`);
    console.log('');
    
    if (summary.changes.length > 0) {
      console.log('=== Changes Made ===');
      for (const change of summary.changes) {
        console.log(`${change.file}: ${change.dependency} ${change.oldVersion} → ${change.newVersion} (${change.section})`);
      }
      console.log('');
    }
    
    if (summary.errors.length > 0) {
      console.log('=== Errors ===');
      for (const error of summary.errors) {
        console.log(`${error.file || 'Unknown'}: ${error.error}`);
      }
      console.log('');
    }
    
    // Output JSON summary for piping to other scripts
    const jsonSummary = {
      timestamp: new Date().toISOString(),
      filesUpdated: summary.totalFilesUpdated,
      dependenciesUpdated: summary.totalDependenciesUpdated,
      changes: summary.changes,
      errors: summary.errors
    };
    
    console.log(JSON.stringify(jsonSummary, null, 2));
    
  } catch (error) {
    console.error('Error processing analysis data:', error.message);
    process.exit(1);
  }
}

main(); 