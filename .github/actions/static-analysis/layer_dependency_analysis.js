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

    // Get all dependencies from both files
    const deps1 = this._getAllDependencies(packageJson1);
    const deps2 = this._getAllDependencies(packageJson2);

    // Compare dependencies
    for (const [dep, version1] of Object.entries(deps1)) {
      const version2 = deps2[dep];
      
      if (version2 === undefined) {
        report.missingInSecond.push({
          dependency: dep,
          version: version1
        });
      } else if (version1 !== version2) {
        report.mismatches.push({
          dependency: dep,
          version1,
          version2
        });
      }
    }

    // Find dependencies that exist only in second file
    for (const [dep, version2] of Object.entries(deps2)) {
      if (deps1[dep] === undefined) {
        report.missingInFirst.push({
          dependency: dep,
          version: version2
        });
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
    let output = '';

    if (report.mismatches.length > 0) {
      output += '\nMismatched Dependencies:\n';
      report.mismatches.forEach(({ dependency, version1, version2 }) => {
        output += `- ${dependency}: ${version1} vs ${version2}\n`;
      });
    }

    if (report.missingInFirst.length > 0) {
      output += '\nDependencies Missing in First File:\n';
      report.missingInFirst.forEach(({ dependency, version }) => {
        output += `- ${dependency}: ${version}\n`;
      });
    }

    if (report.missingInSecond.length > 0) {
      output += '\nDependencies Missing in Second File:\n';
      report.missingInSecond.forEach(({ dependency, version }) => {
        output += `- ${dependency}: ${version}\n`;
      });
    }

    return output || 'No differences found between package.json files.';
  }
}

class LayerDependencyAnalysis {
  constructor(comparator) {
    this.comparator = comparator;
  }

  run(layerPackageJson, domainPackageJsons) {
    console.log('Running layer dependency analysis');

    const reports = domainPackageJsons.map(domainPackageJson => {
      return {
        project: domainPackageJson.project,
        report: this.comparator.compareDependencies(layerPackageJson, domainPackageJson.packageJson)
      };
    });

    const reportsWithWarnings = reports.filter(report => report.report.mismatches.length > 0);

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

// Example usage:
const comparator = new PackageJsonDependencyComparator();

const layerDependencyAnalysis = new LayerDependencyAnalysis(comparator);

const layerPackageJson = require(process.argv[2]);
const domains = JSON.parse(process.argv[3]); // {"include": [{"project": "domain1"}, {"project": "domain2"}]}

const domainPackageJsons = domains.include.map(domain => {
  return {
    project: domain.project,
    packageJson: require(`./domains/${domain.project}/package.json`)
  };
});

layerDependencyAnalysis.run(layerPackageJson, domainPackageJsons);