## What you learned

- KAITO is a Kubernetes operator that manages model lifecycle on AKS — it provisions nodes, downloads model weights, and runs an inference server, all driven by a single `Workspace` custom resource.
- Enabling KAITO on AKS is one Terraform flag: `ai_toolchain_operator_enabled = true`.
- A KAITO `Workspace` ties together: an instance type, a label selector, and an inference template (or a preset name).
- The `kaito.sh/enablelb` annotation is convenient for testing but unsuitable for production — there is no authentication on the inference endpoint.
- The model exposes a standard OpenAPI-style `/chat` endpoint, callable from anywhere with HTTP access.

## Next steps

- Try a different custom model by editing [`assets/kubernetes/kaito_custom_cpu_model.yaml`](../../assets/kubernetes/kaito_custom_cpu_model.yaml) and re-applying.
- Explore the other manifest templates in [`assets/kubernetes/`](../../assets/kubernetes/) — private HuggingFace, Azure storage, Azure ML, and KAITO presets.
- Read the [KAITO docs](https://github.com/kaito-project/kaito) for fine-tuning and GPU presets.
- For production, replace the LoadBalancer annotation with an Ingress controller, add authentication, and consider AAD-integrated RBAC on the cluster.
