The scripts in this directory helps in setting up Lambda Services using Serverless framework. 

<b>Serverless</b> is a framework for managing and deploying functions in different cloud providers like AWS, GCP, Azure, etc. Use the link below to know more about serverless: https://www.serverless.com/

## Installing Serverless
Serverless comes as a npm package. We need to install it globally so that `serverless` is available as a cli to all the users.
```buildoutcfg
npm install -g serverless
```

### Create a serverless package
The `package` command creates an artifact zip containing all the dependencies to deploy the functions on the AWS. It also creates two additional files
- cloud-formation-template-create-stack.json: This file contains the information about how to deploy the functions using CloudFormation
- serverless-state.json: This file is used internally by serverless to perform the deployment operation. It contains all the metadata about the functions defined in the serverless.yml
```buildoutcfg
sls package -s <qa|uat|prod> -p <package_dir>
    where 
    -s, --stage is the environment of deployment
    -p, --package is the directory where the package will be generated. Default is .serverless in the current directory
```

### Deploy a serverless package
The deploy command deploys the lambda service in the AWS infrastructure. If the -p option is not provided, serverless will internally run the `sls package` command to create the packages in the directory `.serverless` in the current working directory. It will then deploy the package in AWS.
```buildoutcfg
sls deploy -s <qa|uat|prod> -p <package_dir>
 where 
    -s, --stage is the environment of deployment
    -p, --package is the directory where the package will be generated. Default is .serverless in the current directory
```