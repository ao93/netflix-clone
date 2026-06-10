# Troubleshooting Log — DevSecOps Netflix Clone Project
**Date:** June 4, 2026  
**Engineer:** Adolfo Ovalles  
**Project:** Netflix Clone on AWS with Jenkins CI/CD

---

## Issue 1 — EC2 SSH Connection Timeout

### Problem
Could not SSH into EC2 instance (`jenkins-server`) from local Mac terminal. 
Connection timed out on port 22.

### Environment
- Local machine: MacBook Air (Apple Silicon), macOS
- EC2 instance: `m7i-flex.large`, Ubuntu 22.04, `us-east-2`
- Home network with IPv6

### Symptoms
```bash
ssh -i ~/.ssh/myawskey.pem ubuntu@3.139.68.62
# ssh: connect to host 3.139.68.62 port 22: Operation timed out

nc -zv 3.139.68.62 22
# nc: connectx to 3.139.68.62 port 22 (tcp) failed: Operation timed out
```

### Diagnosis Steps
1. Checked security group inbound rules — port 22 was restricted to a saved IP
2. Ran `curl ifconfig.me` — discovered machine was on IPv6, not IPv4
3. Security group only had an IPv4 SSH rule — no IPv6 rule existed
4. Tested with `nc -zv` to confirm port 22 was unreachable at network level
5. Tried EC2 Instance Connect via browser — also failed initially
6. Added IPv6 rule to security group — EC2 Instance Connect worked

### Resolution
Added inbound rules to `jenkins-sg`:
- SSH port `22` → Anywhere-IPv4 (`0.0.0.0/0`)
- SSH port `22` → Anywhere-IPv6 (`::/0`)

### Tools Used
- `curl ifconfig.me` — identify public IP and IP version
- `nc -zv` — test port reachability
- AWS EC2 Instance Connect — browser-based fallback when local SSH fails
- AWS Security Groups — firewall rules for EC2

---

## Issue 2 — Jenkins Package Not Available on Ubuntu 25.04

### Problem
Jenkins could not be installed via `apt-get` on the EC2 instance.

### Symptoms
E: Package 'jenkins' has no installation candidate

### Root Cause
The EC2 instance was running **Ubuntu 25.04 (Resolute)** — too new for 
Jenkins apt repository which only supports up to Ubuntu 22.04 LTS.

### Resolution
Installed Jenkins as a `.war` file instead of via apt:
```bash
wget https://get.jenkins.io/war-stable/latest/jenkins.war -O /opt/jenkins.war
```
Then created a `systemd` service to run it:
```bash
cat > /etc/systemd/system/jenkins.service << 'EOF'
[Unit]
Description=Jenkins
After=network.target

[Service]
ExecStart=/usr/bin/java -jar /opt/jenkins.war --httpPort=8080
User=root
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable jenkins
systemctl start jenkins
```

### Lesson Learned
Always check OS compatibility before installing software. Jenkins apt 
repository does not support bleeding-edge Ubuntu releases. Using the 
`.war` file is a universal fallback that works on any Java-compatible OS.

---

## Issue 3 — Jenkins Fails to Start: Java Version Too Old

### Problem
Jenkins service kept failing immediately after starting.

### Symptoms
Running with Java 17 from /usr/lib/jvm/java-17-openjdk-amd64, which is older than the minimum required version (Java 21). Supported Java versions are: [21, 25]

### Root Cause
Jenkins 2.555.2 requires Java 21 minimum. Java 17 was installed.

### Resolution
```bash
apt-get install -y openjdk-21-jdk
systemctl restart jenkins
```

### Lesson Learned
Always check the Java version requirements for the Jenkins version 
being installed. Jenkins regularly updates its minimum Java requirement. 
Use `journalctl -fu jenkins` to read live logs when troubleshooting 
service failures — it reveals the exact error immediately.

---

## Issue 4 — Jenkins UI Not Accessible on Port 8080

### Problem
Browser could not reach `http://3.139.68.62:8080` after Jenkins was running.

### Diagnosis Steps
1. Confirmed Jenkins was running: `systemctl status jenkins` showed `active (running)`
2. Checked security group — port 8080 rule was IPv6 only
3. Ran `curl -4 ifconfig.me` on Mac — got IPv4 address `47.17.123.91`
4. Ran `curl ifconfig.me` — got IPv6 address initially, confusing the diagnosis
5. Ran `ifconfig | grep "inet "` — confirmed Mac has both IPv4 and IPv6

### Resolution
Added a new inbound rule to `jenkins-sg`:
- Custom TCP port `8080` → My IP (`47.17.123.91/32`)

### Lesson Learned
When troubleshooting connectivity issues always check:
1. Is the service actually running? (`systemctl status`)
2. What is your actual public IP? (`curl -4 ifconfig.me` for IPv4)
3. Does the security group have a rule for that exact IP and port?
4. Is the rule IPv4 or IPv6? They are separate rules in AWS.

Always use `curl -4 ifconfig.me` to force IPv4 detection — plain 
`curl ifconfig.me` may return IPv6 which needs different security group rules.

---

## Key Takeaways

1. **IPv4 vs IPv6 matters in AWS** — security group rules are separate for 
   each. Always add both when setting up a new instance.

2. **`journalctl -fu servicename`** is the fastest way to debug why a 
   systemd service is failing.

3. **`nc -zv host port`** is the fastest way to test if a port is reachable 
   before wasting time on SSH config.

4. **`curl -4 ifconfig.me`** forces IPv4 — useful when your network 
   uses both IPv4 and IPv6.

5. **Jenkins `.war` file** is a universal installation method when the 
   apt repository doesn't support your OS version.

6. **Always check Java version requirements** before installing Jenkins — 
   requirements change with each major release.

## Reflection

This troubleshooting session taught me that real-world DevOps is not just 
about following steps — it's about systematically diagnosing why something 
isn't working. Each issue I hit had a logical root cause that I found by 
asking the right questions: Is the service running? Is the port open? 
Is the IP correct? Is the OS compatible?

These are exactly the skills that matter in a DevOps engineering role — 
staying calm, reading error messages carefully, and working through problems 
one layer at a time.


## Issue 5 — Jenkins UI Unreachable on Port 8080 (ISP Port Blocking)

**Date:** June 8, 2026
**Engineer:** Adolfo Ovalles
**Project:** Netflix Clone on AWS with Jenkins CI/CD

---

### Problem
Jenkins was confirmed running on EC2 but the UI was unreachable 
from local Mac browser on port 8080. Connection timed out every time.

### Environment
- Local machine: MacBook Air (Apple Silicon), macOS
- EC2 instance: `m7i-flex.large`, Ubuntu 26.04, `us-east-2`
- Home network ISP: `165.155.x.x` (managed/corporate ISP network)
- Jenkins running on port `8080` via `.war` file

### Symptoms
```bash

### Tools Used
- `systemctl status jenkins` — confirm service is running
- `ss -tlnp` — confirm port is listening on EC2
- `curl http://localhost:8080` — test internal EC2 connectivity
- `nc -zv host port` — test external port reachability
- `traceroute -n` — identify where packets are dropping
- `curl -4 ifconfig.me` — identify current public IPv4 address
- SSH tunnel (`-L` flag) — bypass ISP port blocking

### Lesson Learned
Always test connectivity in layers when troubleshooting network issues:
1. Is the service running? (`systemctl status`)
2. Is it listening on the right port? (`ss -tlnp`)
3. Is it accessible internally? (`curl localhost:PORT`)
4. Is the security group correct? (AWS console)
5. Is it reachable externally? (`nc -zv` and `traceroute`)

If all layers check out but external access still fails, the 
problem is upstream — ISP or network blocking. SSH tunneling 
is the professional solution to bypass port restrictions without 
changing the application or infrastructure.

### Reflection
This issue taught me that infrastructure problems have layers.
Jenkins was working perfectly — the EC2, the service, the security 
group were all configured correctly. The problem was completely 
outside AWS. Real DevOps troubleshooting means ruling out each 
layer systematically until you find the one that's broken.

The SSH tunnel solution is a technique used by DevOps engineers 
daily when working with restrictive networks, corporate firewalls, 
and cloud infrastructure. Knowing how to use it confidently is a 
practical skill that directly translates to the job.

## Issue 6 — EKS Cluster Creation Failed: IAM Permission Errors

**Date:** June 9, 2026
**Engineer:** Adolfo Ovalles
**Project:** Netflix Clone on AWS with Jenkins CI/CD

---

### Problem
Could not create EKS cluster from Jenkins EC2 using eksctl. 
Multiple IAM permission errors blocked the operation.

### Environment
- EC2 instance: `jenkins-server` with IAM role `jenkins-ec2-role`
- Tool: `eksctl version 0.227.0`
- Region: `us-east-2`

### Symptoms
```bash
eksctl create cluster --name netflix-cluster ...

# Error 1
AccessDeniedException: User: arn:aws:sts::445160884854:assumed-role/
jenkins-ec2-role is not authorized to perform: 
eks:DescribeClusterVersions

# Error 2
UnauthorizedOperation: You are not authorized to perform: 
ec2:DescribeInstanceTypeOfferings
```

### Diagnosis Steps
1. Ran `eksctl create cluster` — got `eks:DescribeClusterVersions` denied
2. Checked IAM role policies — found policies were not saved from 
   earlier session
3. Re-attached all required AWS managed policies to `jenkins-ec2-role`
4. Rebooted EC2 to refresh IAM credentials
5. Ran eksctl again — new error: `ec2:DescribeInstanceTypeOfferings` denied
6. Root cause: existing AWS managed policies don't cover all actions 
   eksctl needs
7. Created custom IAM policies to grant full access to required services

### Resolution

**Step 1** — Created custom policy `EKSFullAccessCustom`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "eks:*",
      "Resource": "*"
    }
  ]
}
```

**Step 2** — Created custom policy `JenkinsFullAccessCustom`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "eks:*",
        "cloudformation:*",
        "iam:*",
        "ecr:*",
        "ssm:GetParameter"
      ],
      "Resource": "*"
    }
  ]
}
```

**Step 3** — Attached both custom policies to `jenkins-ec2-role`

**Step 4** — Ran eksctl again — cluster creation started successfully

### Final IAM Role Policy List
- `AmazonEC2ContainerRegistryFullAccess`
- `AmazonEKSClusterPolicy`
- `AmazonEKSServicePolicy`
- `AmazonEKSWorkerNodePolicy`
- `AWSCloudFormationFullAccess`
- `IAMFullAccess`
- `EKSFullAccessCustom` (custom)
- `JenkinsFullAccessCustom` (custom)

### Tools Used
- `eksctl` — EKS cluster creation tool
- AWS IAM — Identity and Access Management
- AWS CloudFormation — infrastructure provisioning used by eksctl

### Lesson Learned
eksctl requires many granular AWS permissions across multiple services
— EC2, EKS, CloudFormation, IAM, and SSM. The standard AWS managed 
EKS policies don't cover everything eksctl needs. 

When hitting IAM permission errors:
1. Read the exact action being denied in the error message
2. Create a custom policy that allows that action
3. Attach it to the role
4. Reboot the EC2 to refresh credentials if changes don't take effect

In production, use least-privilege policies. For a portfolio/learning 
project, broad custom policies are acceptable to unblock progress.

### Reflection
IAM permission issues are one of the most common problems DevOps 
engineers face on AWS. Every real-world AWS project involves debugging 
IAM. The key skill is reading the error message carefully — it tells 
you exactly which action is denied and which resource it applies to.
Learning to create custom IAM policies is a core DevOps competency 
that directly translates to the job.

## Issue 7 — Disk Full on Jenkins EC2 (ENOSPC)

**Date:** June 9, 2026
**Engineer:** Adolfo Ovalles
**Project:** Netflix Clone on AWS with Jenkins CI/CD

---

### Problem
Jenkins pipeline failed during `yarn install` with `ENOSPC: no space left on device`.

### Symptoms
```bash
error https://registry.yarnpkg.com/esbuild-freebsd-64/-/esbuild-freebsd-64-0.15.12.tgz: 
ENOSPC: no space left on device, write
```

### Root Cause
EC2 root volume was only 8GB despite setting 30GB at launch — 
the storage setting didn't save properly during instance creation.
Installing Java, Jenkins, Docker, Trivy, Node.js, npm and yarn 
filled the 8GB volume completely.

### Diagnosis
```bash
df -h
# /dev/root  6.7G  6.6G  27M  100%  /
```

### Resolution
1. Go to AWS console → EC2 → Volumes
2. Select the jenkins-server volume
3. Actions → Modify volume → change 8 to 30
4. Then on EC2:
```bash
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/root
df -h
# /dev/root  28G  6.6G  22G  24%  /
```

### Lesson Learned
Always verify the actual disk size after launching an EC2 instance.
The AWS console storage setting doesn't always apply correctly.
Run `df -h` as one of the first checks when setting up a new server.

---

## Issue 8 — yarn not found on Jenkins EC2

**Date:** June 9, 2026
**Engineer:** Adolfo Ovalles
**Project:** Netflix Clone on AWS with Jenkins CI/CD

---

### Problem
Jenkins pipeline failed with `yarn: not found` during Install Dependencies stage.

### Symptoms
```bash
/root/.jenkins/workspace/netflix-clone-pipeline@tmp/durable-88d3bec2/script.sh.copy: 
1: yarn: not found
```

### Root Cause
yarn was not installed globally on the EC2 instance.
Jenkins installs Node.js in its workspace but not yarn globally.

### Resolution
```bash
sudo apt-get install -y npm
sudo npm install -g yarn
yarn --version
# 1.22.22
```

### Lesson Learned
Jenkins tool installations are workspace-scoped. Global tools like
yarn need to be installed separately on the EC2 instance.

---

## Issue 9 — Dockerfile Using npm ci Instead of yarn

**Date:** June 9, 2026
**Engineer:** Adolfo Ovalles
**Project:** Netflix Clone on AWS with Jenkins CI/CD

---

### Problem
Docker build failed because Dockerfile used `npm ci` but the app 
uses yarn and has no `package-lock.json`.

### Symptoms
```bash
npm error The `npm ci` command can only install with an existing 
package-lock.json or npm-shrinkwrap.json with lockfileVersion >= 1.
```

### Resolution
Updated Dockerfile to use yarn:
```dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile
COPY . .
ARG TMDB_V3_API_KEY
ENV VITE_APP_TMDB_V3_API_KEY=$TMDB_V3_API_KEY
RUN yarn build

FROM nginx:stable-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Lesson Learned
Always match the package manager in the Dockerfile with the one
used in the project. If the project has a `yarn.lock` file, use
yarn in the Dockerfile. If it has `package-lock.json`, use npm.

---

## Issue 10 — EKS Nodes Too Small for ArgoCD (t3.micro)

**Date:** June 9, 2026
**Engineer:** Adolfo Ovalles
**Project:** Netflix Clone on AWS with Jenkins CI/CD

---

### Problem
ArgoCD pods were stuck in `Pending` state after installation on EKS.

### Symptoms
```bash
kubectl get pods -n argocd
# All pods showing 0/1 Pending

kubectl describe pod argocd-server -n argocd
# 0/2 nodes are available: 2 Too many pods.
```

### Root Cause
`t3.micro` instances have a maximum of 4 pods per node.
EKS system pods already used all available pod slots before
ArgoCD pods could be scheduled.

### Resolution
1. Deleted old nodegroup:
```bash
eksctl delete nodegroup \
  --cluster netflix-cluster \
  --region us-east-2 \
  --name netflix-nodes \
  --disable-eviction
```
2. Created new nodegroup with `t3.small`:
```bash
eksctl create nodegroup \
  --cluster netflix-cluster \
  --region us-east-2 \
  --name netflix-nodes-v2 \
  --node-type t3.small \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed
```

### Lesson Learned
`t3.micro` is too small for production Kubernetes workloads.
Use at minimum `t3.small` for EKS nodes. Always check the
pod limit per instance type before choosing your node size.
For reference:
- t3.micro: 4 pods max
- t3.small: 11 pods max
- t3.medium: 17 pods max

---

## 🎉 Pipeline SUCCESS — Build 10

**Date:** June 9, 2026

### What worked end to end:
1. Jenkins pulled code from GitHub
2. yarn install — dependencies installed
3. Docker build — Netflix clone image built successfully
4. Trivy scan — 1 HIGH vulnerability found (libxml2 CVE-2026-6732)
5. ECR push — image pushed to AWS ECR
6. Manifests repo updated — deployment.yaml image tag updated
7. ArgoCD detected change and deployed to EKS

### Total builds to get pipeline working: 10
### Total issues resolved: 10

### Reflection
Getting a DevSecOps pipeline working from scratch is never
a straight line. Every error was a learning opportunity:
- IAM permissions in AWS require granular configuration
- Disk space management is critical on EC2
- Package managers must match between local dev and Docker
- Kubernetes node sizing directly impacts pod scheduling
- Network troubleshooting requires a layered approach

Each of these issues is something real DevOps engineers face
daily. Having documented solutions makes you a stronger
candidate and a better engineer.