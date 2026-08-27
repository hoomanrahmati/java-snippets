## AWS

[back](../terraform/README.md)

### activate local stack ui:

[https://app.localstack.cloud/inst/default/resources](https://app.localstack.cloud/inst/default/resources)

`npm install -g @localstack/lstk`

`-e LOCALSTACK_AUTH_TOKEN="ls-vufE7848-QOWA-gIFo-pUJo-dejamuwEe949"`

Personal Auth Token, for localStack(us-east-1)

```bash
# ls-vufE7848-QOWA-gIFo-pUJo-dejamuwEe949

docker run \
  -e LOCALSTACK_AUTH_TOKEN="ls-vufE7848-QOWA-gIFo-pUJo-dejamuwEe949" \
  -p 4566:4566 \
  --name localStack-1 \
  localstack/localstack:latest
```

```bash
alias sflocal='aws --endpoint-url http://localhost:8083 --region us-east-1'
```

```bash
aws --version
# aws-cli/2.34.57 Python/3.14.5 Windows/11 exe/AMD64

```

```bash
$ aws configure --profile local

Tip: You can deliver temporary credentials to the AWS CLI using your AWS Console session by running the command 'aws login'.

# AWS Access Key ID [None]: dummy
# AWS Secret Access Key [None]: dummy
# Default region name [None]: us-east-1
# Default output format [None]:

```

```bash
$ aws stepfunctions --endpoint-url http://localhost:8083 --profile local list-state-machines
{
    "stateMachines": [
        {
            "stateMachineArn": "arn:aws:states:us-east-1:123456789012:stateMachine:HelloWorld",
            "name": "HelloWorld",
            "type": "STANDARD",
            "creationDate": "2026-06-01T18:59:08.620000+03:30"
        }
    ]
}

```

```bash
$ AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy  \
aws stepfunctions --endpoint-url http://localhost:8083 --region us-east-1 create-state-machine \
  --name "HelloWorld" \
  --definition '{
    "Comment": "A simple Hello World workflow",
    "StartAt": "Hello",
    "States": {
      "Hello": {
        "Type": "Pass",
        "Result": "Hello from Step Functions Local!",
        "End": true
      }
    }
  }' \
  --role-arn "arn:aws:iam::123456789012:role/DummyRole"

```

```bash
$ aws login --region us-east-1
```

```bash
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test aws --endpoint-url=http://localhost:4566 s3 ls

```

```bash
aws configure

# AWS Access Key ID [None]: test
# AWS Secret Access Key [None]: test
# Default region name [None]: us-east-1
# Default output format [None]: json

```

```bash
aws configure --profile localstack

# AWS Access Key ID [None]: test
# AWS Secret Access Key [None]: test
# Default region name [None]: us-east-1
# Default output format [None]: json

```

```bash
aws --endpoint-url=http://localhost:4566 --profile localstack s3 ls
```

```bash
$ aws stepfunctions --endpoint-url=http://localhost:8083 list-state-machines
```

```bash

```
