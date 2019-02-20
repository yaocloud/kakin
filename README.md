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
username: "username"
tenant: "your-admin-tenant"
password: "password"
```

Or set with environment variable.

```
export OS_AUTH_URL=<your openstack auth url>
export OS_USER=<your username>
export OS_TENANT_NAME=<your tenant>
export OS_PASSWORD=<your password>
```

You can get resource usage with following command.

```
$ kakin -f cost.yaml
```
