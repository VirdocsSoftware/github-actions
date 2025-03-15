class StaticAnalysis {
    constructor(dataProvider, process) {
        this.dataProvider = dataProvider;
        this.process = process;
    }

    isCommitHash(ref) {
        return /^[0-9a-f]{40}$/.test(ref);
    }

    findYamlFiles(dir) {
        let results = [];
        const list = this.dataProvider.readDirectory(dir);
        list.forEach(file => {
            const fullPath = this.dataProvider.path.join(dir, file);
            const stat = this.dataProvider.getFileStats(fullPath);
            if (stat && stat.isDirectory()) {
                results = results.concat(this.findYamlFiles(fullPath));
            } else if (file.endsWith('.yml') || file.endsWith('.yaml')) {
                results.push(fullPath);
            }
        });
        return results;
    }

    scanFile(filePath) {
        const content = this.dataProvider.readFile(filePath);
        const regex = /uses:\s*[\w-]+\/[\w-]+@([\w-.]+)/g;
        let match;
        let warnings = [];
        while ((match = regex.exec(content)) !== null) {
            const ref = match[1];
            if (!this.isCommitHash(ref)) {
                warnings.push(`Warning: In file ${filePath}, '${match[0]}' does not use a commit hash.`);
            }
        }
        return warnings;
    }

    run() {
        const workflowDir = this.dataProvider.path.join(this.process.cwd(), '.github', 'workflows');
        if (!this.dataProvider.fileExists(workflowDir)) {
            console.error(`Error: Directory ${workflowDir} does not exist.`);
            this.process.exit(1);
        }

        const yamlFiles = this.findYamlFiles(workflowDir);
        let allWarnings = [];

        yamlFiles.forEach(filePath => {
            const warnings = this.scanFile(filePath);
            allWarnings = allWarnings.concat(warnings);
        });

        if (allWarnings.length > 0) {
            allWarnings.forEach(warning => console.warn(warning));
            console.log('To fix these issues, refer to the solution in the following Jira ticket: https://virdocs.atlassian.net/browse/RD-2964');
            this.process.exit(1); // Exit with non-zero code if warnings are found
        } else {
            console.log('No issues found. All action calls use commit hashes.');
            this.process.exit(0);
        }
    }
}

class DataProvider {
    constructor(fs, path) {
        this.fs = fs;
        this.path = path;
    }

    readDirectory(dir) {
        return this.fs.readdirSync(dir);
    }

    readFile(filePath) {
        return this.fs.readFileSync(filePath, 'utf8');
    }

    fileExists(filePath) {
        return this.fs.existsSync(filePath);
    }

    getFileStats(filePath) {
        return this.fs.statSync(filePath);
    }
}

// Dependency injection
const fs = require('fs');
const path = require('path');
const process = require('process');

const dataProvider = new DataProvider(fs, path);
const staticAnalysis = new StaticAnalysis(dataProvider, process);
staticAnalysis.run();
