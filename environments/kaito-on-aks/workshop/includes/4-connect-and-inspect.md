## Goal

Connect `kubectl` to the new cluster and walk through everything KAITO created.

## 1. Get cluster credentials

```bash
az aks get-credentials \
  --resource-group "$RG_NAME" \
  --name "$(terraform output -raw cluster_name)"
```

## 2. Look at the cluster

```bash
kubectl get nodes
kubectl get namespaces
```

You should see the system node pool plus, eventually, a KAITO-provisioned node tagged for the workspace.

## 3. Inspect the KAITO Workspace

```bash
kubectl get workspace -n kaito-custom-cpu-inference
kubectl describe workspace bloomz-560m-workspace -n kaito-custom-cpu-inference
```

Walk through the `Status` block. KAITO reports:

- `ResourceReady` — the underlying VM/node is up
- `InferenceReady` — the inference pod is healthy
- `WorkspaceReady` — the whole thing is good to go

## 4. Watch the inference pod

```bash
kubectl get pods -n kaito-custom-cpu-inference -w
```

Press `Ctrl+C` once the pod shows `Running` with `Ready 1/1`. On CPU this can take several minutes — the container has to download ~2.2 GB of model weights from HuggingFace before the readiness probe passes.

## 5. Tail the logs

```bash
POD=$(kubectl get pods -n kaito-custom-cpu-inference -l app=bloomz-560m -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n kaito-custom-cpu-inference "$POD" --tail=100
```

You should see HuggingFace `transformers` downloading config + tokenizer + weights, then `accelerate` launching the inference server on port 5000.

## 6. Inspect the auto-created LoadBalancer

```bash
kubectl get svc bloomz-560m-workspace -n kaito-custom-cpu-inference
```

The `EXTERNAL-IP` column will say `<pending>` for a minute or two while Azure provisions the public IP, then show a real IP. This service was created automatically because of the `kaito.sh/enablelb: "True"` annotation on the `Workspace`.
