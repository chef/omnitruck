## Deployment to kubernetes

There are a few things needed before deploying to kubernetes:

Create a redis elasticcache instance in aws:

* Name: omnitruck-ENV
* Description: Omnitruck ENV
* Engine version compatibility: 5.0.0 (default)
* Port: 6379: default
* Parameter group: default.redis5.0
* Node type: cache.t2.micro (dev/acceptance), cache.t2.?? (production)
* Number of replicas: 2
* Multi-AZ with Auto-Failover: yes
* Subnet group: kubernetes-subnet-group
  * If this group doesn't exist, create it and add the subnets of the
    kubernetes VPC in there
* Preferred zone: No preference
* Security groups: omnitruck-redis
  * If this group doesn't exist, create it and add the following rules:
    * Port 6379 TCP from the kubernetes IP range
    * Port 6379 TCP from the VPN IP range
* Security group should allow port 6379 from the kubernetes IP range
* Encryption at-rest: No
* Encryption in-transit: Yes (this turns on the Redis AUTH option)
* Redis AUTH: Yes
* Redis AUTH Token: generate one
* Enable automatic backups: On (default). Backup preferences can be left at
  defaults or changed as desired.
* Topic for SNS notification: Choose a topic that will notify you by email.
* Everything else can be left at defaults

Once the redis instance is created, create a kubernetes secret with the URL
of the redis instance:

```
kubectl -n omnitruck create secret generic omnitruck-ENV
  --from-literal=redis_url=redis://:AUTHTOKEN@redis.example.com:6379
```

Once the redis cluster and secret are created, omnitruck should be able to be
deployed through kubenetes and buildkite. This process may be automated in
future with something like terraform.
