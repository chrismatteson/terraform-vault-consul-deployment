import urllib2
import boto3
import os

def lambda_handler(event, context):
  url = "{}:8500/v1/operator/license".format(event['consul_server'])
  LICENSE = os.environ.get('LICENSE')
  data = LICENSE
  req = urllib2.Request(url, data)
  try:
      token = event['token']
      req.add_header('X-Consul-Token', token)
  except:
      print('no token defined')
  req.get_method = lambda: 'PUT'
  f = urllib2.urlopen(req)
  for x in f:
      print(x)
  f.close()
