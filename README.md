# github-actions
Used to store GitHub actions for use across the enterprise

## References for Included Actions

### CFN Formatting (rain)

#### How to Format Locally
If you have made a change to the CloudFormation templates you need to be sure to format them and commit those changes to pass the GitHub actions validations.
1. Format command: `rain fmt ./py/template.yml ./ts/template.yml -w`
- *NOTE:* the -w ensures you write the changes back to the same file
- *NOTE:* the path to your file names may be different, in this example we are assuming you have two template files located at `./py/template.yml` and `./ts/template.yml` in your repo.
2. Save the file and commit + push these changes to the repo

#### Installation (rain)
- Installation instructions for local usage: https://github.com/aws-cloudformation/rain
- *NOTE:* At time of writing the recommendation is to install via brew: `brew install rain`

#### Example - Failed Validation, Need to Reformat (rain fmt)
In this example, I need to run rain fmt, save, and push the changes due to ./ts/template.yml formatting mistakes.
```
Run ./rain fmt --verify ./py/template.yml ./ts/template.yml
./py/template.yml: formatted OK
./ts/template.yml: would reformat
Error: Process completed with exit code 1.
```

#### Example - Successful Validation (rain fmt)
```
Run ./rain fmt --verify ./py/template.yml ./ts/template.yml
./py/template.yml: formatted OK
./ts/template.yml: formatted OK
```

### CFN Linting (cfn-lint)
The cfn-lint tool checks the CFN template files adhere to the following rules: https://github.com/aws-cloudformation/cfn-lint/blob/main/docs/rules.md#rules-1

#### Installation (cfn-lint)
- Installation instructions for local usage: https://github.com/aws-cloudformation/cfn-lint
- *NOTE:* At time of writing the recommendation is to install via brew: `brew install cfn-lint`

#### Example - Warning (cfn-lint)

When the GitHub action runs to lint the CFN, you may see a warning, prefixed with a W which will fail the build.
```
Run cfn-lint --version
cfn-lint 0.79.3
Running CFN Linter on ./py/template.yml ./ts/template.yml
W2001 Parameter SnsFilePubArn not used.
Warning: ./ts/template.yml:20:3

Error: Process completed with exit code 4.
```

For example to resolve the error output above I need to:
(1) remove the unused CFN parameter value for SnsFilePubArn,
(2) save the file,
(3) commit the change and
(4) push those changes.


#### Example - Successful Validation (cfn-lint)

```
Run cfn-lint --version
cfn-lint 0.79.3
Running CFN Linter on ./py/template.yml ./ts/template.yml
```
