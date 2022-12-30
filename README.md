
# Keycloak As Auth Solution

Current project was created to demonstrate possibility of scaling for a keycloak setup.

### Hardware

| Parameter               | Value                               |
| ----                    | ----                                |
| Model Name              | MacBook Pro                         |
| Model Identifier	      | MacBookPro18,2                      |
| Model Number            | Z14X000AEFN/A                       |
| Chip                    | Apple M1 Max                        |
| Total Number of Cores   | 10 (8 performance and 2 efficiency) |
| Memory                  | 32 GB                               |


## Setup 

Start with a bit of the disclaimer, while this project will showcase scalability it will also differ from real setup in several ways.
Main difference that is also a bottleneck here is the postgres setup, in aws you'd use [Aurora](https://aws.amazon.com/rds/aurora/), while here you just have single self-hosted instance.
Two other notable differences is that it was run using docker with "single-node" setup, instead of using kubernetes cluster with multiple nodes.

Otherwise we use multiple keycloak containers that are able efficiently utilize CPUs available available from Docker.
Primitive nginx load balancer was added in front of keycloak containers and distributed cache was enabled, so all containers can work well together.

## A bit about cache

Keycloak containers can run on multiple nodes and communicate using [infinispan](https://infinispan.org/).
This project has a really simple setup for [distributed cache](https://www.keycloak.org/server/caching), by just enabling it like this:

```yaml
services:
    # ...
    keycloak:
        # ...
        environment:
            # ...
            KC_CACHE: ispn
```

But it is possible to configure it in a lot more detail specific to our cloud provider.

## How to run some things locally

```sh

# Following command will start docker network with 8 keycloak containers, I will suggest using number of containers close to your available CPUs for best performance
# For example you can notice results like this from ./token_creation_batch.rb script
    # # Keycloak x2 | CPUs x6
    # avg = 1.3766662633333333s | min = 0.261287s | max = 1.893616s
    # 95% = 1.7480137999999998 | 99% = 1.8668644200000002
    # # Keycloak x5 | CPUs x6
    # avg = 1.512128194999998s | min = 0.373115s | max = 1.740685s
    # 95% = 1.6608370499999998 | 99% = 1.70301576
    # # Keycloak x8 | CPUs x6
    # avg = 1.7733442708333345s | min = 0.685783s | max = 2.290649s
    # 95% = 2.1064974 | 99% = 2.25301887
docker compose up --scale keycloak=8

# It's possible to check current resources through `stats` command, where you will notice that only 2 where CPUs are at max usage:
# 1 - Startup, which is somewhat of the characteristic for java-based applications. It doesn't take long and we can avoid being affected by it, by setting up `ready`/`health` endpoint and checking them before marking pod as `ready`
# 2 - Batch logins or other creation of resources
# Otherwise it will stay at minimum few percent
docker stats

# OUTPUT EXAMPLE:
# CONTAINER ID   NAME                           CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O         PIDS
# 928784694ab8   keycloak-bench-kc-database-1   0.00%     516.9MiB / 9.718GiB   5.19%     74.4MB / 21.3MB   22.9MB / 219MB    207
# 0046b5d6860c   keycloak-bench-keycloak-3      2.28%     631.1MiB / 9.718GiB   6.34%     39.5MB / 19.1MB   24.2MB / 934kB    103
# ffd2230a2586   keycloak-bench-keycloak-4      1.89%     620.8MiB / 9.718GiB   6.24%     39.9MB / 30.9MB   19.8MB / 983kB    95
# 5333b0cd420a   keycloak-bench-keycloak-8      1.92%     655.2MiB / 9.718GiB   6.58%     38.8MB / 18.4MB   15.3MB / 1.02MB   102
# 1bc0ec29f339   keycloak-bench-keycloak-10     1.20%     651.9MiB / 9.718GiB   6.55%     39.1MB / 18.9MB   14.8MB / 1.01MB   95
# e7c2fa124706   keycloak-bench-keycloak-1      2.37%     650.6MiB / 9.718GiB   6.54%     39.7MB / 18.9MB   15.7MB / 995kB    97
# 75fd9822676a   keycloak-bench-keycloak-6      1.41%     668.2MiB / 9.718GiB   6.72%     40.6MB / 26.5MB   15.4MB / 1.05MB   98
# 71160d3fe202   keycloak-bench-keycloak-5      2.98%     608MiB / 9.718GiB     6.11%     38.2MB / 17.9MB   14.8MB / 1.03MB   96
# 2fdb1c6a377b   keycloak-bench-keycloak-2      5.69%     602.1MiB / 9.718GiB   6.05%     39.1MB / 26.1MB   14.8MB / 999kB    88
# 595c3f9a5f0e   nginx                          0.00%     6.352MiB / 9.718GiB   0.06%     78.9MB / 64.1MB   1.94MB / 4.1kB    2
```

```sh
# With default config following script will create 10000 users
# On my machine (MB with M1 Max) with keycloak x8 and cpu x10 it's done in about 70 sec
./user_creation.rb

# OUTPUT EXAMPLE:
# ...
# test_user_395 | create_user_response = 201 | elapsed = 1.131182
# test_user_349 | create_user_response = 201 | elapsed = 1.144446
# test_user_366 | create_user_response = 201 | elapsed = 1.143655
# test_user_236 | create_user_response = 201 | elapsed = 1.167677
# ---- 400 users created ----
# ---- completed in 3.030384 sec ----
```


```sh
# Following script will infinitely create tokens for random users from prev script (200 per batch)
./token_creation_batch.rb

# OUTPUT EXAMPLE:
# ...
# test_user_9453 | token_response = 200 | elapsed = 0.071474
# test_user_7385 | token_response = 200 | elapsed = 0.071676
# test_user_2316 | token_response = 200 | elapsed = 0.072605
# test_user_2384 | token_response = 200 | elapsed = 0.08367
# avg = 0.06528886538461537s | min = 0.050857s | max = 0.111951s
# 95% = 0.09083614999999999 | 99% = 0.10547179000000004
```

# Summary

## Scalability

As you can see from the data above, it's possible to quite easily scale keycloak horizontally by running multiple containers and use distributed cache.

Even though current setup uses a single node, there's no difference in implementation for multi-node cluster where you can spread pods across them.

PS While this work doesn't attempt scale to millions of users there are a lot of examples from different teams that do that (for example 45+ million here https://www.youtube.com/watch?v=XydR3QKkQIM)

## Cost?

Overall I would say single developer can support this setup, while hardware cost really depends on a couple of variables:

> How much users we expect to be using auth functionality at the same time?

While I did collect information that we have about 12000 user identities across 92 integrators, it's difficult to estimate how often we can get bursts of hundreds of users logging in at the same time.

> What would be the acceptable latency for 95 & 99 percentiles?

This is very much connected to the first point, even current setup can easily login couple of hundreds of users at the same time with latency under 2 sec, and if that happens once a week that could be acceptable depending on requirements. 

> What is the total amount of users do we want to accommodate in a near future?

This parameter needs to be accounted for, but it would be at the bottom of priorities because I don't really see a possibility to use considerable amount of disk space without millions of users.

## Paid support for Keycloak & RedHat SSO

There is no paid support for Keycloak specifically.

...

## 
