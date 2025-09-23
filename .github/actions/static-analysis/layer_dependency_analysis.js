const fs = require('fs');

class PackageJsonDependencyComparator {
  /**
   * Compares dependencies between two package.json files
   * @param {Object} packageJson1 - First package.json object
   * @param {Object} packageJson2 - Second package.json object
   * @returns {Object} Report containing mismatched dependencies
   */
  compareDependencies(packageJson1, packageJson2) {
    const report = {
      mismatches: [],
      missingInFirst: [],
      missingInSecond: []
    };
    // console.log('Comparing dependencies:', packageJson1, packageJson2);

    // Get all dependencies from both files
    const deps1 = this._getAllDependencies(packageJson1);
    const deps2 = this._getAllDependencies(packageJson2);
    // console.log('Dependencies:', deps1, deps2);

    // Compare dependencies
    for (const [dep, version1] of Object.entries(deps1)) {
      const version2 = deps2[dep];
      // console.log('Comparing dependency:', dep, version1, version2);

      if (version2 === undefined) {
        continue;  // we don't care about missing dependencies
      } else if (version1 !== version2) {
        report.mismatches.push({
          dependency: dep,
          version1,
          version2
        });
      }
    }

    // Find dependencies that exist only in second file
    for (const [dep] of Object.entries(deps2)) {
      if (deps1[dep] === undefined) {
        continue;  // we don't care about missing dependencies
      }
    }

    return report;
  }

  /**
   * Extracts all dependencies from a package.json object
   * @param {Object} packageJson - package.json object
   * @returns {Object} Combined dependencies object
   */
  _getAllDependencies(packageJson) {
    return {
      ...packageJson.dependencies || {},
      ...packageJson.devDependencies || {},
      ...packageJson.peerDependencies || {},
      ...packageJson.optionalDependencies || {}
    };
  }

  /**
   * Formats the comparison report into a readable string
   * @param {Object} report - Comparison report
   * @returns {string} Formatted report
   */
  formatReport(report) {
    let parts = [];

    if (report.mismatches.length > 0) {
      const mismatchItems = report.mismatches.map(({ dependency, version1, version2 }) =>
        `${dependency}:${version1}vs${version2}`
      ).join(', ');
      parts.push(`Mismatched against layer: [${mismatchItems}]`);
    }

    if (report.missingInFirst.length > 0) {
      const missingFirstItems = report.missingInFirst.map(({ dependency, version }) =>
        `${dependency}:${version}`
      ).join(', ');
      parts.push(`Missing in First: [${missingFirstItems}]`);
    }

    if (report.missingInSecond.length > 0) {
      const missingSecondItems = report.missingInSecond.map(({ dependency, version }) =>
        `${dependency}:${version}`
      ).join(', ');
      parts.push(`Missing in Second: [${missingSecondItems}]`);
    }

    return parts.length > 0 ? parts.join(' | ') : 'No differences found between package.json files.';
  }
}

class LayerDependencyAnalysis {
  constructor(comparator) {
    this.comparator = comparator;
  }

  run(layerPackageJson, domainPackageJsons, outputFormat = 'console') {
    if (outputFormat !== 'json') {
      console.log('Running layer dependency analysis');
    }

    const reports = domainPackageJsons.map(domainPackageJson => {
      return {
        project: domainPackageJson.project,
        report: this.comparator.compareDependencies(layerPackageJson, domainPackageJson.packageJson)
      };
    });

    const reportsWithWarnings = reports.filter(report => report.report.mismatches.length > 0);

    if (outputFormat === 'json') {
      // Output structured JSON data for piping to other scripts
      const jsonOutput = {
        timestamp: new Date().toISOString(),
        layerPackageJson: layerPackageJson.name || 'unknown',
        totalDomainsAnalyzed: domainPackageJsons.length,
        domainsWithMismatches: reportsWithWarnings.length,
        reports: reports.map(report => ({
          project: report.project,
          hasMismatches: report.report.mismatches.length > 0,
          mismatches: report.report.mismatches,
          missingInFirst: report.report.missingInFirst,
          missingInSecond: report.report.missingInSecond,
          formattedReport: this.comparator.formatReport(report.report)
        }))
      };
      
      console.log(JSON.stringify(jsonOutput, null, 2));
    } else {
      // Original console output behavior
      if (reportsWithWarnings.length > 0) {
        console.log('Reports with mismatched dependencies:');
        reportsWithWarnings.forEach(report => {
          // output warning to github actions
          console.log(`::warning file=${report.project}/package.json::${this.comparator.formatReport(report.report)}`);
        });
      } else {
        console.log('No mismatched dependencies found');
      }
    }
  }
}

function main() {
  const args = process.argv.slice(2);
  const jsonOutput = args.includes('--json');
  const filteredArgs = args.filter(arg => arg !== '--json');

  if (filteredArgs.length < 2) {
    console.error('Usage: node layer_dependency_analysis.js [--json] <layer-package-json> <domains>');
    console.error('  --json: Output structured JSON data instead of console warnings');
    process.exit(1);
  }

  if (!jsonOutput) {
    console.log('Layer package.json:', filteredArgs[0]);
    console.log('Domains:', filteredArgs[1]);
    console.log('Current working directory:', process.cwd());
  }

  // Example usage:
  const comparator = new PackageJsonDependencyComparator();

  const layerDependencyAnalysis = new LayerDependencyAnalysis(comparator);

  if (!jsonOutput) {
    console.log('Reading layer package.json:', process.cwd() + '/' + filteredArgs[0]);
  }
  const layerPackageJson = JSON.parse(fs.readFileSync(process.cwd() + '/' + filteredArgs[0], 'utf8'));
  const domains = JSON.parse(filteredArgs[1]); // {"include": [{"project": "domain1"}, {"project": "domain2"}]}

  const domainPackageJsons = domains.include.filter(domain => domain.project != '.').map(domain => {
    try {
      const packageJson = JSON.parse(fs.readFileSync(process.cwd() + '/domains/' + domain.project + '/package.json', 'utf8'));
      return {
        project: domain.project,
        packageJson
      };
    } catch (error) {
      if (!jsonOutput) {
        console.error('Error parsing package.json for domain:', domain.project, error);
      }
      return undefined;
    }
  }).filter(domain => domain !== undefined);

  // print the test plan
  if (!jsonOutput) {
    console.log('Test plan:');
    console.log('Layer package.json:', layerPackageJson);
    console.log('Domains:', domains);
    // console.log('Domain package.json:', JSON.stringify(domainPackageJsons, null, 2));
  }

  layerDependencyAnalysis.run(layerPackageJson, domainPackageJsons, jsonOutput ? 'json' : 'console');
}

main();