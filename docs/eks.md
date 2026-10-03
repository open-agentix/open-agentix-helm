# Amazon EKS

This guide walks through [`examples/values-eks.yaml`](../examples/values-eks.yaml): open-agentix on
EKS with Amazon Bedrock reached through a VPC interface endpoint, IAM Roles for Service Accounts
(IRSA), the AWS Load Balancer Controller (ALB), Amazon RDS for PostgreSQL and ElastiCache.

## 1. Network: VPC interface endpoints

Create interface endpoints (with private DNS) in the private subnets of the cluster for:

| Service | Why |
| --- | --- |
| `com.amazonaws.<region>.bedrock-runtime` | model invocations (`InvokeModel`, `Converse`) |
| `com.amazonaws.<region>.sts` | IRSA: `AssumeRoleWithWebIdentity` |

Attach a security group that allows TCP 443 from the node/pod security group. With private DNS
enabled the regional host names resolve to the endpoint; set `aws.bedrock.vpcEndpointUrl` anyway
to pin the endpoint-specific DNS name (it is passed to the AWS SDK as `endpoint`):

```yaml
aws:
  region: eu-central-1
  bedrock:
    enabled: true
    vpcEndpointUrl: https://vpce-0123456789abcdef0-abcdefgh.bedrock-runtime.eu-central-1.vpce.amazonaws.com
    clearance: confidential     # highest data classification agents may send to Bedrock
```

The chart appends this entry to `OAX_PROVIDERS` (`kind: bedrock`). Agents reference it by
`name` (default `bedrock`). If egress must go through a proxy instead, set
`aws.bedrock.proxyUrl` (per provider) and/or `proxy.httpsProxy` (process wide; the AWS SDK
honours `HTTPS_PROXY`).

Allow the worker to reach the endpoints in the NetworkPolicy (CIDR of the endpoint subnets):

```yaml
networkPolicy:
  egress:
    providers:
      - to: [{ ipBlock: { cidr: 10.20.64.0/22 } }]
        ports: [{ protocol: TCP, port: 443 }]
```

NetworkPolicies on EKS need the VPC CNI network policy agent (`enableNetworkPolicy: "true"` on
the `vpc-cni` add-on) or another policy engine (Calico, Cilium).

## 2. IAM: IRSA for the worker

Only the worker calls Bedrock. Create an IAM role with a trust policy for the cluster's OIDC
provider, restricted to the worker ServiceAccount:

```json
{
  "Effect": "Allow",
  "Principal": { "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/<ID>" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "oidc.eks.eu-central-1.amazonaws.com/id/<ID>:sub": "system:serviceaccount:openagentix:oax-open-agentix-worker",
      "oidc.eks.eu-central-1.amazonaws.com/id/<ID>:aud": "sts.amazonaws.com"
    }
  }
}
```

Permission policy (least privilege; list only the models you allow):

```json
{
  "Effect": "Allow",
  "Action": ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream", "bedrock:Converse", "bedrock:ConverseStream"],
  "Resource": ["arn:aws:bedrock:eu-central-1::foundation-model/anthropic.claude-*"]
}
```

Optionally add `aws:SourceVpce` conditions so the role only works through your endpoint.
Annotate the ServiceAccount:

```yaml
serviceAccount:
  worker:
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/openagentix-bedrock-invoke
```

The EKS pod identity webhook injects `AWS_ROLE_ARN` and `AWS_WEB_IDENTITY_TOKEN_FILE`; the chart
sets `AWS_REGION` and `AWS_STS_REGIONAL_ENDPOINTS=regional`. No access keys are configured
anywhere. The pod keeps `automountServiceAccountToken: false`; IRSA uses its own projected token.
EKS Pod Identity works as well: create the association for the same ServiceAccount and leave the
annotation empty.

## 3. Ingress: AWS Load Balancer Controller

```yaml
ingress:
  enabled: true
  className: alb
  host: agents.example.com
  annotations:
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
    alb.ingress.kubernetes.io/healthcheck-path: /readyz
  tls:
    enabled: true        # TLS is terminated by the ALB with the ACM certificate
    secretName: ""
```

With `target-type: ip` the ALB connects to the pods directly from the VPC: allow the VPC (or ALB
subnet) CIDR in `networkPolicy.ingress.from`. `config.trustProxy` becomes `true` automatically
when the ingress is enabled. Run streams use server-sent events; if streams of long runs are cut
after the ALB idle timeout (default 60 s), raise it with
`alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=300`.

## 4. Database and cache

- Amazon RDS / Aurora PostgreSQL 16+: `sslmode: verify-full`. The RDS CA bundle is not in the
  image's trust store: mount it from a ConfigMap (`api.extraVolumes`/`extraVolumeMounts`, same
  for the worker) and point `NODE_EXTRA_CA_CERTS` at it (`config.extraEnv`). Create the roles from the platform's
  `deploy/sql/roles.sql`; give the migrations Job the owner role via
  `externalDatabase.migrations.*`.
- ElastiCache for Valkey/Redis with in-transit encryption and AUTH: store the full
  `rediss://:<token>@host:6379` URL in a Secret and reference it with `cache.existingSecret`.
- Restrict `networkPolicy.egress.database` / `.cache` to the subnets of RDS and ElastiCache.

## 5. Install

```bash
kubectl create namespace openagentix
kubectl label namespace openagentix pod-security.kubernetes.io/enforce=restricted
# create the Secrets listed at the top of examples/values-eks.yaml, then:
helm install oax charts/open-agentix -n openagentix -f examples/values-eks.yaml
```

## 6. Worker nodes as Jobs (v0.2)

`runners.kubernetesJob` prepares the Kubernetes Job runner: a dedicated namespace with PodSecurity
`restricted`, a Role that lets the worker create Jobs there, a token-less ServiceAccount for run
pods (annotate it for IRSA if runs call Bedrock themselves) and a default-deny NetworkPolicy that
only allows DNS and the control node API. Leave it disabled until the platform ships the runner.
