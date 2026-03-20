# runbook.md

## Purpose
Operational runbook for deployment, rollback, and common troubleshooting.

## Scope
- Services: ingestion, validation, reporting, postgres
- Environments: local (Minikube), production (DOKS)

## Prerequisites
- Docker installed
- kubectl configured
- Access to Kubernetes cluster and namespace
- Container registry credentials
- Kubernetes manifests ready (`deployment.yaml`, `service.yaml`, secrets)

## Environment Variables (Example)
- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD` (from Secret)
- `JWT_PUBLIC_KEY` or `API_KEY`
- `LOG_LEVEL`

## Deployment Procedure

### 1) Build and Push Images
1. Build each service image.
2. Tag image with commit SHA.
3. Push to registry.

Example commands:
```bash
# Replace placeholders with actual repo/image names
# docker build -t <registry>/ingestion:<sha> ./ingestion
# docker push <registry>/ingestion:<sha>
```

### 2) Apply Database First
1. Apply postgres StatefulSet/Deployment + PVC.
2. Wait until DB pod is ready.
3. Run schema migration (`schema.sql`).

### 3) Apply App Services
1. Apply Secrets and ConfigMaps.
2. Deploy ingestion, validation, reporting.
3. Apply Services and Ingress.
4. Apply HPA for ingestion service.

### 4) Post-Deploy Validation
1. Check pod status:
```bash
kubectl get pods -n <namespace>
```
2. Check rollout:
```bash
kubectl rollout status deployment/ingestion -n <namespace>
kubectl rollout status deployment/validation -n <namespace>
kubectl rollout status deployment/reporting -n <namespace>
```
3. Health checks:
```bash
curl -s https://<host>/healthz
curl -s https://<host>/readyz
```
4. Smoke test transaction flow:
- POST one transaction
- Verify `RECEIVED` then `VALID/REJECTED`
- Call one report endpoint

## Rollback Procedure

### Fast Rollback (Deployment)
```bash
kubectl rollout undo deployment/ingestion -n <namespace>
kubectl rollout undo deployment/validation -n <namespace>
kubectl rollout undo deployment/reporting -n <namespace>
```

### Verify Rollback
```bash
kubectl rollout status deployment/ingestion -n <namespace>
kubectl get rs -n <namespace>
```

### Database Rollback
- Prefer forward-fix migration when possible.
- If rollback required:
  - Restore from backup/snapshot.
  - Re-run compatible schema version.
- Never drop production tables without approved backup.

## Common Incidents and Actions

### 1) 5xx Spike on Ingestion
- Check logs for DB connection/auth errors.
- Confirm Secret values and DB reachability.
- Scale ingestion deployment temporarily.
- If newly released version is faulty, perform rollout undo.

### 2) Validation Backlog Keeps Growing
- Verify validation pods are running.
- Check worker logs for lock/query errors.
- Confirm `status='RECEIVED'` index exists.
- Increase validation worker replicas if CPU bound.

### 3) HPA Not Scaling
- Confirm metrics server is installed and healthy.
- Check CPU requests/limits are set in deployment.
- Describe HPA object:
```bash
kubectl describe hpa ingestion-hpa -n <namespace>
```

### 4) Database Pod Restarting
- Check PVC bound status.
- Verify resource limits and OOM events.
- Inspect postgres logs for disk/full errors.
- If storage issue, expand volume (if provider supports).

### 5) Auth Failures Suddenly Increase
- Check token expiration and signing key rotation status.
- Verify system clock skew across nodes.
- Roll keys carefully and redeploy auth-dependent services.

## Monitoring During Incident
- Watch these first:
  - API error rate
  - P95 latency
  - Validation backlog
  - Pod restarts
  - DB connections

## Communication Template (Internal)
- Incident start time:
- Impacted components:
- User impact:
- Current status:
- Mitigation in progress:
- Next update ETA:

## Recovery Checklist
- [ ] Service health endpoints return OK
- [ ] Error rate back to baseline
- [ ] Backlog stabilized or draining
- [ ] No abnormal pod restarts
- [ ] Post-incident summary recorded

## Change Management Notes
- Use commit SHA image tags for reproducibility.
- Keep one-click rollback available at all times.
- Do not run schema-breaking changes with app release in same step unless tested.
