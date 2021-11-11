# Build and upload the docker image to ECR

### Build the docker image locally
Make sure to run the command in the directory containing the `Dockerfile`.
```buildoutcfg
cd docker_image
sudo docker build -t asdf-ubuntu-focal:1.0.0 .
```

### Create a repository in ECR
Make sure the AWS credentials have been exported as environment variables before running the below command
```buildoutcfg
aws ecr create-repository 
		--repository-name asdf-ubuntu-focal 
		--image-scanning-configuration scanOnPush=false
```

### Login to ECR
The below command will perform docker login into the ECR repository
```buildoutcfg
aws ecr get-login-password | sudo docker login --username AWS --password-stdin 842031058638.dkr.ecr.us-east-2.amazonaws.com
```

### Tag the image with the ECR Repo
Tag the local image you built above to the ECR repository name you created.
```buildoutcfg
sudo docker tag asdf-ubuntu-focal:1.0.0 842031058638.dkr.ecr.us-east-2.amazonaws.com/asdf-ubuntu-focal:1.0.0
```

### Push the image to ECR
A simple docker push will push the above image to the ECR provided it is tagged correctly and you are logged in to ECR
```buildoutcfg
sudo docker push 842031058638.dkr.ecr.us-east-2.amazonaws.com/asdf-ubuntu-focal:1.0.0
```