# 🎬 Netflix Clone — DevSecOps on AWS

A full-stack Netflix clone deployed on AWS using a complete DevSecOps 
pipeline. Built as a portfolio project to demonstrate end-to-end 
CI/CD, container security, Kubernetes orchestration, and GitOps deployment.

![Netflix Clone](docs/screenshots/app.png)

---

## 🏗️ Architecture

Developer → GitHub → Jenkins → Docker Build → Trivy Scan →
Amazon ECR → ArgoCD → Amazon EKS → Live App

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React + TypeScript + Vite |
| Data | TMDB API |
| CI/CD | Jenkins |
| Security Scan | Trivy |
| Container Registry | Amazon ECR |
| Orchestration | Amazon EKS (Kubernetes 1.34) |
| GitOps | ArgoCD |
| Web Server | nginx (alpine) |
| Infrastructure | AWS (EC2, EKS, ECR, IAM, VPC) |

---

## 🔐 DevSecOps Pipeline

Every git push triggers the full pipeline:

1. **Checkout** — Jenkins pulls latest code from GitHub
2. **Install Dependencies** — yarn install
3. **Docker Build** — Multi-stage build (Node → nginx)
4. **Trivy Scan** — Container vulnerability scanning (HIGH/CRITICAL)
5. **Push to ECR** — Docker image pushed to Amazon ECR
6. **Update Manifests** — Jenkins updates image tag in manifests repo
7. **ArgoCD Sync** — Detects git change, deploys to EKS automatically

---

## 📁 Repository Structure

### App Repo (`netflix-clone`)
├── Jenkinsfile              # CI/CD pipeline definition
├── Dockerfile               # Multi-stage Docker build
├── nginx.conf               # SPA routing config
├── sonar-project.properties # SonarQube config
├── src/                     # React app source
│   ├── components/          # UI components
│   ├── store/               # Redux store + TMDB API slices
│   ├── pages/               # HomePage, GenreExplore, WatchPage
│   └── constant/            # API config
└── docs/
└── troubleshooting.md   # Real-world issues + solutions

### Manifests Repo (`netflix-clone-manifest`)
├── argocd-app.yaml          # ArgoCD Application definition
├── base/
│   ├── namespace.yaml       # netflix namespace
│   ├── deployment.yaml      # Kubernetes Deployment
│   ├── service.yaml         # LoadBalancer Service
│   └── hpa.yaml             # Horizontal Pod Autoscaler
└── overlays/
├── staging/             # Staging environment
└── production/          # Production environment

---

## 🚀 AWS Infrastructure

| Resource | Type | Purpose |
|----------|------|---------|
| Jenkins Server | EC2 m7i-flex.large | CI/CD orchestration |
| EKS Cluster | Kubernetes 1.34 | App hosting |
| EKS Nodes | 2x t3.small | Worker nodes |
| ECR | Private registry | Docker images |
| Load Balancer | NLB | App traffic |

---

## 🛡️ Security

- **Trivy** scans every Docker image for OS and library CVEs
- **IAM least privilege** — Jenkins EC2 uses Instance Profile
- **Private ECR** — container images not publicly accessible
- **K8s Secrets** — TMDB API key stored as Kubernetes secret
- **Security Groups** — restrictive inbound rules per service

---

## 🐛 Troubleshooting

This project encountered and resolved **12 real-world issues** including:

- EC2 SSH connection timeout (IPv4/IPv6 security group rules)
- Jenkins installation on Ubuntu 25.04 (unsupported OS)
- Java version incompatibility (Jenkins requires Java 21+)
- ISP port blocking (resolved with SSH tunnel)
- EKS IAM permission errors (custom IAM policies)
- Disk space exhaustion on EC2 (volume resize)
- EKS node pod limits (t3.micro → t3.small upgrade)
- Vite build-time environment variable injection
- TMDB API authentication (v3 key vs v4 JWT token)

Full documentation: [troubleshooting.md](docs/troubleshooting.md)

---

## 🔧 Local Development

```bash
# Clone the repo
git clone https://github.com/ao93/netflix-clone.git
cd netflix-clone

# Install dependencies
yarn install

# Create .env file
echo "VITE_APP_TMDB_V3_API_KEY=your_tmdb_read_access_token" > .env
echo "VITE_APP_API_ENDPOINT_URL=https://api.themoviedb.org/3" >> .env

# Run locally
yarn dev
```

---

## 📊 Pipeline Results

- **Total builds to production:** 23
- **Security vulnerabilities found:** 1 HIGH (libxml2 CVE-2026-6732)
- **Uptime:** 99%+ via Kubernetes rolling updates
- **Zero-downtime deploys:** Enabled via `maxUnavailable: 0`

---

## 👨‍💻 Engineer

**Adolfo Ovalles**  
DevOps/Cloud Engineer  
[LinkedIn](https://linkedin.com/in/aovalles/) | [GitHub](https://github.com/ao93)

---

## 📝 License

MIT



