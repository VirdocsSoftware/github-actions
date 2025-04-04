class StaticAnalysis {
    constructor(dataProvider, process, ignoredAccounts = []) {
        this.dataProvider = dataProvider;
        this.process = process;
        this.ignoredAccounts = ignoredAccounts;
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
        const regex = /uses:\s*([\w-]+\/[\w-]+)@([\w-.]+)/g;
        let match;
        let warnings = [];
        while ((match = regex.exec(content)) !== null) {
            const ref = match[2];
            const account = match[1].split('/')[0];
            if (this.ignoredAccounts.includes(account)) {
                continue;
            }
            if (!this.isCommitHash(ref)) {
                warnings.push(`Warning: In file ${filePath}, '${match[0]}' does not use a commit hash.`);
            }
        }
        return warnings;
    }

    run() {
        const workflowDir = this.dataProvider.path.join(this.process.cwd(), '.github', 'workflows');
        const domainsDir = this.dataProvider.path.join(this.process.cwd(), 'domains');
        let allWarnings = [];

        // Scan .github/workflows directory if it exists
        if (this.dataProvider.fileExists(workflowDir)) {
            const yamlFiles = this.findYamlFiles(workflowDir);
            yamlFiles.forEach(filePath => {
                const warnings = this.scanFile(filePath);
                allWarnings = allWarnings.concat(warnings);
            });
        }

        // Scan domains/*/.github/**/*.yml files if domains directory exists
        if (this.dataProvider.fileExists(domainsDir)) {
            const domains = this.dataProvider.readDirectory(domainsDir);
            domains.forEach(domain => {
                const domainPath = this.dataProvider.path.join(domainsDir, domain);
                const domainGithubPath = this.dataProvider.path.join(domainPath, '.github');
                
                if (this.dataProvider.fileExists(domainGithubPath)) {
                    const yamlFiles = this.findYamlFiles(domainGithubPath);
                    yamlFiles.forEach(filePath => {
                        const warnings = this.scanFile(filePath);
                        allWarnings = allWarnings.concat(warnings);
                    });
                }
            });
        }

        if (allWarnings.length > 0) {
            allWarnings.forEach(warning => {
                // Extract file path and line number if available
                const fileMatch = warning.match(/In file (.*?),/);
                const filePath = fileMatch ? fileMatch[1] : '';
                const relativePath = filePath ? this.dataProvider.path.relative(this.process.cwd(), filePath) : '';
                
                // Output warning using GitHub's Workflow Commands
                console.log(`::warning file=${relativePath}::${warning}`);
            });
            console.log('To fix these issues, refer to the solution in the following Jira ticket: https://virdocs.atlassian.net/browse/RD-2964');
            this.process.exit(0); // TODO: Exit with non-zero code if warnings are found
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
const ignoredAccounts = (process.env.IGNORED_ACCOUNTS || '').split(',');

const dataProvider = new DataProvider(fs, path);
const staticAnalysis = new StaticAnalysis(dataProvider, process, ignoredAccounts);
staticAnalysis.run();
