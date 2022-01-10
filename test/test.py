import redis


def test_connection_status(r):
    resp = r.ping()
    #print(".    ", resp)
    assert resp == True, "Insertion should returm 'True'"
    print ("  Test connection OK")

def test_insert_key(r):
    resp = r.set('key1', '123')
    #print(".    ", resp)
    assert resp == True, "Insertion should returm 'True'"
    print ("  Test insertion OK")

def test_read_key(r):
    resp = r.get('key1')
    #print(".    ", resp)
    assert resp == "123", "Get key1 should returm '123'"
    print ("  Test read OK")

def test_delete_key(r):
    resp = r.delete('key1')
    #print(".    ", resp)
    assert resp == 1, "Delete key1 should returm '1'"
    print ("  Test delete OK")

r = redis.StrictRedis(host='127.0.0.1',
                        port=6379,
                        decode_responses=True,
                        password='defaultRedisPasswordToBeSetUpWithinEnv',
#                        ssl=True,
#                        ssl_keyfile='./ssl/redis_client.key',
#                        ssl_certfile='./ssl/redis_client.pem',
#                        ssl_cert_reqs='required',
#                        ssl_ca_certs='./ssl/rootCA.pem',
                        db=0,
                        socket_connect_timeout=10)

try:
    test_connection_status(r)
    test_insert_key(r)
    test_read_key(r)
    test_delete_key(r)
    print("Tests successful")
except Exception as e:
    print(e)
    print("Tests failed")
