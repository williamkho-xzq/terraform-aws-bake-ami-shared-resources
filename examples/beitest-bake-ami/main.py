import boto3
import json
import zipfile
import io
from pprint import pprint

codepipeline_client =  boto3.client('codepipeline')
job_id = ""

def report_failure(error):
    codepipeline_client.put_job_failure_result(jobId=job_id, failureDetails={
        "type": "JobFailed",
        "message": str(error)
    })
    print(error)

def report_success():
    codepipeline_client.put_job_success_result(jobId=job_id)

def get_acount_ids():
    account_ids = []
    try:
        ssm_client = boto3.client('ssm')
        # TODO
        account_ids = ssm_client.get_parameter(Name="ami-target-accounts")["Parameter"]["Value"]
        pprint(account_ids)
    except Exception as error:
        report_failure(error)
        raise
    return account_ids.split(",")

def get_file_from_s3_zip(bucket_name, key_name, file_name):
    s3_client = boto3.client('s3')
    file_content = ""
    try:
        # from https://github.com/carloscarcamo/aws-lambda-unzip-py/blob/master/unzip.py
        zip_object = s3_client.get_object(Bucket=bucket_name, Key=key_name)
        with io.BytesIO(zip_object["Body"].read()) as tf:
            # rewind the file
            tf.seek(0)
            # Read the file as a zipfile and process the members
            with zipfile.ZipFile(tf, mode='r') as myzip:
                file_content = str(myzip.read(file_name),"UTF-8").replace("\n","")
    except Exception as error:
        report_failure(error)
        raise
    return file_content


def share_image(image_id, account_ids):
    try:
        ec2_client = boto3.client('ec2')
        response = ec2_client.modify_image_attribute(
            Attribute='launchPermission',
            OperationType='add',
            UserIds=account_ids,
            ImageId=image_id
        )
        print("Success! AMI " + image_id + "has been shared to accounts:")
        pprint(account_ids)
    except Exception as error:
        report_failure(error)
        raise

def get_image_id(codepipeline_job):
    image_id = ""
    try:
        ami_manifest_artifact=[artifact for artifact in codepipeline_job['data']['inputArtifacts'] if artifact['name'] == 'PackerManifest'][0]
        ami_manifest_artifact_s3_location = ami_manifest_artifact["location"]["s3Location"]
        json_string=get_file_from_s3_zip(ami_manifest_artifact_s3_location["bucketName"], ami_manifest_artifact_s3_location["objectKey"], "packer-manifest.json")
        packer_manifest= json.loads(json_string)
        image_id = packer_manifest["builds"][0]["artifact_id"].split(":")[1]
        print(image_id)
    except Exception as error:
        report_failure(error)
        raise
    return image_id

def handler(event, context):
    global job_id
    codepipeline_job = event["CodePipeline.job"]
    job_id = codepipeline_job["id"]
    print(event)
    print(job_id)
    account_ids = get_acount_ids()
    image_id = get_image_id(codepipeline_job)
    share_image(image_id, account_ids)
    report_success()
