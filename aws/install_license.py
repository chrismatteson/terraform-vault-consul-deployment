import urllib2
import boto3

CONSUL_SERVER = os.environ.get('
BUCKET_NAME = os.environ.get('BUCKET_NAME')
LICENSE = client.get_object(Bucket='BUCKET_NAME', Key='consul_license')
data = '{LICENSE}'
url = 'http://localhost:8080/firewall/rules/0000000000000001'
req = urllib2.Request(url, data, {'Content-Type': 'application/json'})
f = urllib2.urlopen(req)
for x in f:
    print(x)
f.close()
