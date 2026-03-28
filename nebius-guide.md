# Nebius Token Factory — Complete Guide

## Overview
Nebius Token Factory = OpenAI-compatible API running on H100 GPUs with open-source models.
- **API base URL:** `https://api.tokenfactory.nebius.com/v1/`
- **Auth:** Bearer token (API key from dashboard)
- **SDK:** Standard OpenAI Python/JS SDK, just change base_url
- **Hackathon credits:** $200 per team (promo code via Slack)

## Setup
```bash
pip install openai
export NEBIUS_API_KEY=<your_key>
```

Sign up: https://tokenfactory.nebius.com/
Docs: https://docs.tokenfactory.nebius.com/quickstart

---

## 1. Inference (Calling Models)

### Basic Chat Completion
```python
from openai import OpenAI

client = OpenAI(
    base_url="https://api.tokenfactory.nebius.com/v1/",
    api_key=os.environ["NEBIUS_API_KEY"],
)

response = client.chat.completions.create(
    model="meta-llama/Llama-3.3-70B-Instruct",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Explain HRV in simple terms."}
    ],
    temperature=0.7,
    max_tokens=512,
)
print(response.choices[0].message.content)
```

### Embeddings
```python
response = client.embeddings.create(
    model="BAAI/bge-en-icl",  # or whatever embedding model is available
    input="heart rate variability depression correlation"
)
vector = response.data[0].embedding
```

### Available Capabilities
- Chat completions (text → text)
- Embeddings (text → vector)
- Image generation
- Vision (image + text → text)
- Function calling / tool use
- Structured JSON output
- Batch inference (bulk processing)
- Document reranking

### Key Models for Inference
- `meta-llama/Llama-3.3-70B-Instruct` — best general-purpose
- `deepseek-ai/DeepSeek-V3-0324` — strong reasoning
- `Qwen/Qwen3-32B` — good multilingual
- Various embedding and vision models

### Multi-Region Endpoints
- EU-North1, EU-West1, US-Central1, ME-West1

---

## 2. Fine-Tuning (Training on Your Data)

### Dataset Format (JSONL)

**Conversational (most common):**
```json
{"messages": [{"role": "system", "content": "You are a clinical assistant."}, {"role": "user", "content": "What is rumination?"}, {"role": "assistant", "content": "Rumination is repetitive negative thinking about past events..."}]}
```

**Instruction pairs:**
```json
{"prompt": "Capital of Australia", "completion": "Canberra"}
```

**Plain text:**
```json
{"text": "Task: Explain compound interest.\n\nAnswer: Compound interest is..."}
```

**Pre-tokenized:**
```json
{"token_ids": [1, 234, 567], "labels": [-100, 234, 567]}
```

Max file size: 5 GB

### Step-by-Step Fine-Tuning

```python
import os, time
from openai import OpenAI

client = OpenAI(
    base_url="https://api.tokenfactory.nebius.com/v1/",
    api_key=os.environ["NEBIUS_API_KEY"],
)

# 1. Upload dataset
training_file = client.files.create(
    file=open("training.jsonl", "rb"),
    purpose="fine-tune",
)
print("Training file ID:", training_file.id)

# Optional: upload validation set
validation_file = client.files.create(
    file=open("validation.jsonl", "rb"),
    purpose="fine-tune",
)

# 2. Create fine-tuning job
job = client.fine_tuning.jobs.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    training_file=training_file.id,
    validation_file=validation_file.id,
    suffix="my-custom-model",
    hyperparameters={
        "batch_size": 8,
        "learning_rate": 1e-5,
        "n_epochs": 3,
        "warmup_ratio": 0.0,
        "weight_decay": 0.0,
        "lora": True,
        "lora_r": 16,
        "lora_alpha": 16,
        "lora_dropout": 0.05,
        "packing": True,
        "max_grad_norm": 1.0,
        "context_length": 8192,
    },
    seed=42,
)
print("Job ID:", job.id, "Status:", job.status)

# 3. Monitor
while job.status not in ["succeeded", "failed", "cancelled"]:
    time.sleep(15)
    job = client.fine_tuning.jobs.retrieve(job.id)
    print(f"Status: {job.status}")

# 4. Check events
events = client.fine_tuning.jobs.list_events(job.id)
for event in events.data:
    print(event.created_at, event.level, "-", event.message)

# 5. Download checkpoints
if job.status == "succeeded":
    checkpoints = client.fine_tuning.jobs.checkpoints.list(job.id).data
    for cp in checkpoints:
        print(f"Checkpoint {cp.id}: step {cp.step_number}")
        os.makedirs(cp.id, exist_ok=True)
        for file_id in cp.result_files:
            file_obj = client.files.retrieve(file_id)
            content = client.files.content(file_id)
            path = os.path.join(cp.id, os.path.basename(file_obj.filename))
            content.write_to_file(path)
            print(f"Saved: {path}")
```

### Models Available for Fine-Tuning

| Family | Sizes | LoRA | Full |
|---|---|---|---|
| Llama 3.1 | 8B, 70B (base + instruct) | Yes | Yes |
| Llama 3.2 | 1B, 3B (base + instruct) | Yes | Yes |
| Llama 3.3 | 70B-Instruct | Yes | Yes |
| Qwen3 | 0.6B to 32B + Coder | Yes | Yes |
| Qwen2.5 | 0.5B to 72B + Coder 32B | Yes | Yes |
| GPT-OSS | 20B, 120B | Yes | Yes |
| DeepSeek | V3-0324, V3.1 | No | Full only (US) |

Context lengths: 8192, 16384, 32768, 65536, 131072 tokens

### Key Hyperparameters
- **batch_size**: 8-32 (larger = more VRAM)
- **learning_rate**: 1e-6 to 5e-5
- **n_epochs**: 1-20 (default 3)
- **lora**: True for LoRA (faster, cheaper), False for full fine-tuning
- **lora_r / lora_alpha**: LoRA rank and scaling (16/16 is good default)
- **context_length**: Use smallest that covers your data
- **packing**: True to pack short samples efficiently

---

## 3. Dedicated Endpoints
Deploy a model instance exclusively for your team. Guaranteed latency.

---

## Budget Estimation ($200 credits)
- Inference (70B model): ~$0.20-0.40 per 1M tokens → thousands of calls
- LoRA fine-tuning (8B): ~$5-20 per run depending on data size
- LoRA fine-tuning (70B): ~$30-100 per run
- Several training runs + extensive inference easily within $200

---

## cURL Quick Reference

### Chat completion
```bash
curl https://api.tokenfactory.nebius.com/v1/chat/completions \
  -H "Authorization: Bearer $NEBIUS_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.3-70B-Instruct",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### Upload file
```bash
curl https://api.tokenfactory.nebius.com/v1/files \
  -H "Authorization: Bearer $NEBIUS_API_KEY" \
  -F "file=@training.jsonl" \
  -F "purpose=fine-tune"
```

### Create fine-tuning job
```bash
curl https://api.tokenfactory.nebius.com/v1/fine_tuning/jobs \
  -X POST \
  -H "Authorization: Bearer $NEBIUS_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.1-8B-Instruct",
    "training_file": "<FILE_ID>",
    "hyperparameters": {"batch_size": 8, "learning_rate": 1e-5, "n_epochs": 3, "lora": true}
  }'
```

### Check job status
```bash
curl https://api.tokenfactory.nebius.com/v1/fine_tuning/jobs/<JOB_ID> \
  -H "Authorization: Bearer $NEBIUS_API_KEY"
```

### List available models
```bash
curl https://api.tokenfactory.nebius.com/v1/models \
  -H "Authorization: Bearer $NEBIUS_API_KEY"
```
