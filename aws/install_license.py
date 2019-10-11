import urllib2
import boto3

CONSUL_SERVER = os.environ.get('
BUCKET_NAME = os.environ.get('BUCKET_NAME')
LICENSE = client.get_object(Bucket='BUCKET_NAME', Key='consul_license')
data = '{LICENSE}'
url = 'https://{URL}:8500/v1/operator/license'
req = urllib2.Request(url, data, {'Content-Type': 'application/json'})
f = urllib2.urlopen(req)
for x in f:
    print(x)
f.close()
