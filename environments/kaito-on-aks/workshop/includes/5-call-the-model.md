## Goal

Send inference requests to the model via the public LoadBalancer endpoint, and optionally from inside the cluster.

## 1. Capture the external IP

```bash
KAITO_IP=$(kubectl get svc bloomz-560m-workspace \
  -n kaito-custom-cpu-inference \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "KAITO endpoint: http://$KAITO_IP"
```

## 2. Health check

```bash
curl http://$KAITO_IP/health
```

## 3. Inspect the API schema

```bash
curl -s http://$KAITO_IP/openapi.json | head
```

KAITO exposes a standard OpenAPI-compatible inference API.

## 4. Sample prompts

**Question answering:**

```bash
curl --max-time 60 -X POST http://$KAITO_IP/chat \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "What sport should I play in rainy weather?",
    "return_full_text": false,
    "generate_kwargs": {
      "max_new_tokens": 256,
      "do_sample": false
    }
  }'
```

**Factual question:**

```bash
curl --max-time 60 -X POST http://$KAITO_IP/chat \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Is a tomato a fruit or a vegetable?",
    "return_full_text": false,
    "generate_kwargs": {
      "max_new_tokens": 256,
      "do_sample": false
    }
  }'
```

**Brief definition:**

```bash
curl --max-time 60 -X POST http://$KAITO_IP/chat \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Answer briefly: What is cloud computing?",
    "return_full_text": false,
    "generate_kwargs": {
      "max_new_tokens": 256,
      "do_sample": false
    }
  }'
```

## 5. Request shape

| Field | Meaning |
|-------|---------|
| `prompt` | The input text the model continues from |
| `return_full_text` | `false` returns only the newly generated tokens |
| `generate_kwargs.max_new_tokens` | Hard cap on generated length |
| `generate_kwargs.do_sample` | `false` = greedy (deterministic), `true` = sampling |

## 6. Optional — call from inside the cluster

This shows the more production-realistic path: an in-cluster client hitting a `ClusterIP` service via DNS, with no public IP involved.

```bash
kubectl run curl-debug \
  -n kaito-custom-cpu-inference \
  -it --restart=Never \
  --image=curlimages/curl \
  -- sh
```

Inside the pod:

```sh
curl http://bloomz-560m-workspace/health

curl -X POST http://bloomz-560m-workspace/chat \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "What is cloud computing?",
    "return_full_text": false,
    "generate_kwargs": { "max_new_tokens": 256, "do_sample": false }
  }'

exit
```

```bash
kubectl delete pod curl-debug -n kaito-custom-cpu-inference
```
