"""Call a deployed SageMaker real-time endpoint (Hugging Face DLC, JSON body)."""
import json
import os
import sys

import boto3


def main() -> None:
    endpoint = os.environ.get("ENDPOINT_NAME", "").strip()
    if not endpoint:
        print("Set ENDPOINT_NAME to the Terraform output `endpoint_name`.", file=sys.stderr)
        sys.exit(1)
    region = os.environ.get("AWS_REGION", "us-east-1")
    default_body = json.dumps({"inputs": "I like you. I love you."})
    body = os.environ.get("PREDICT_BODY", default_body)

    client = boto3.client("sagemaker-runtime", region_name=region)
    response = client.invoke_endpoint(
        EndpointName=endpoint,
        ContentType="application/json",
        Accept="application/json",
        Body=body if isinstance(body, (bytes, bytearray)) else body.encode("utf-8"),
    )
    print(response["Body"].read().decode("utf-8"))


if __name__ == "__main__":
    main()
