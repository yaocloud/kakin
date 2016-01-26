# kakin
OpenStackのリソース使用料金按分ツール

## Usage

```
$ mv cost.yaml.sample cost.yaml
$ vi cost.yaml
```

You need to create configuration file located `~/.kakin` for openstack credential like this.

```
auth_url: "http://your-openstack-host:35357/v2.0/tokens"
management_url: "http://your-openstack-host:8774/v2"
username: "username"
tenant: "your-admin-tenant"
password: "password"
```

You can get resource usage with following command.

```
$ kakin -f cost.yaml
```
