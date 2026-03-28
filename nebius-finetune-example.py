"""
Nebius Token Factory — Fine-Tuning Example
Ready-to-run script for the hackathon.

Setup:
  pip install openai
  export NEBIUS_API_KEY=<your_key>

Prepare your training data as JSONL (see generate_sample_data() below).
"""

import json
import os
import time

from openai import OpenAI

client = OpenAI(
    base_url="https://api.tokenfactory.nebius.com/v1/",
    api_key=os.environ["NEBIUS_API_KEY"],
)


def generate_sample_data(filename: str = "training.jsonl"):
    """Generate sample training data in conversational format.
    Replace this with your actual domain data.
    """
    samples = [
        {
            "messages": [
                {"role": "system", "content": "You are a clinical research assistant specializing in mental health."},
                {"role": "user", "content": "What is metacognitive therapy?"},
                {"role": "assistant", "content": "Metacognitive therapy (MCT) is a psychotherapy approach developed by Adrian Wells that focuses on modifying metacognitive beliefs and processes rather than the content of thoughts. Unlike traditional CBT which challenges specific negative thoughts, MCT targets the thinking styles and beliefs about thinking that maintain psychological disorders. Key techniques include attention training, detached mindfulness, and challenging metacognitive beliefs about worry and rumination."},
            ]
        },
        {
            "messages": [
                {"role": "user", "content": "Explain the relationship between HRV and depression."},
                {"role": "assistant", "content": "Heart rate variability (HRV) is consistently lower in individuals with major depressive disorder compared to healthy controls. Meta-analyses show reduced HRV, particularly in the high-frequency (HF) band reflecting parasympathetic activity, correlates with depression severity. Low HRV reflects autonomic dysregulation and reduced vagal tone, which are both markers and potential mechanisms of depressive states. Longitudinal studies suggest HRV may serve as a biomarker for treatment response and depression risk prediction."},
            ]
        },
        {
            "messages": [
                {"role": "user", "content": "What is the PHQ-9?"},
                {"role": "assistant", "content": "The Patient Health Questionnaire-9 (PHQ-9) is a validated self-report screening tool for depression severity. It consists of 9 items corresponding to DSM-5 diagnostic criteria for major depressive disorder, each scored 0-3 (not at all to nearly every day). Total scores range from 0-27, with severity thresholds: 0-4 minimal, 5-9 mild, 10-14 moderate, 15-19 moderately severe, 20-27 severe depression. It has sensitivity of 88% and specificity of 88% for major depression at a cutoff score of 10."},
            ]
        },
    ]

    with open(filename, "w") as f:
        for sample in samples:
            f.write(json.dumps(sample) + "\n")

    print(f"Generated {len(samples)} samples → {filename}")
    print("NOTE: Replace with your actual domain data (100+ examples recommended)")
    return filename


def upload_dataset(filepath: str):
    """Upload a JSONL dataset to Nebius."""
    result = client.files.create(
        file=open(filepath, "rb"),
        purpose="fine-tune",
    )
    print(f"Uploaded {filepath} → File ID: {result.id}")
    return result.id


def start_finetune(
    training_file_id: str,
    validation_file_id: str | None = None,
    model: str = "meta-llama/Llama-3.1-8B-Instruct",
    suffix: str = "hackathon-v1",
    epochs: int = 3,
    lr: float = 1e-5,
    batch_size: int = 8,
    use_lora: bool = True,
    context_length: int = 8192,
):
    """Create a fine-tuning job."""
    params = {
        "model": model,
        "training_file": training_file_id,
        "suffix": suffix,
        "hyperparameters": {
            "batch_size": batch_size,
            "learning_rate": lr,
            "n_epochs": epochs,
            "lora": use_lora,
            "lora_r": 16,
            "lora_alpha": 16,
            "lora_dropout": 0.05,
            "packing": True,
            "context_length": context_length,
        },
        "seed": 42,
    }
    if validation_file_id:
        params["validation_file"] = validation_file_id

    job = client.fine_tuning.jobs.create(**params)
    print(f"Created fine-tuning job: {job.id}")
    print(f"Model: {model} | LoRA: {use_lora} | Epochs: {epochs}")
    print(f"Status: {job.status}")
    return job


def monitor_job(job_id: str, poll_interval: int = 15):
    """Poll job status until completion."""
    terminal = {"succeeded", "failed", "cancelled"}

    while True:
        job = client.fine_tuning.jobs.retrieve(job_id)
        print(f"[{time.strftime('%H:%M:%S')}] Status: {job.status}")

        if job.status in terminal:
            break
        time.sleep(poll_interval)

    if job.status == "failed":
        print(f"ERROR: {job.error}")
    elif job.status == "succeeded":
        print("Fine-tuning completed successfully!")

    return job


def download_checkpoints(job_id: str, output_dir: str = "checkpoints"):
    """Download model checkpoints from a completed job."""
    checkpoints = client.fine_tuning.jobs.checkpoints.list(job_id).data
    os.makedirs(output_dir, exist_ok=True)

    for cp in checkpoints:
        cp_dir = os.path.join(output_dir, f"step_{cp.step_number}")
        os.makedirs(cp_dir, exist_ok=True)
        print(f"Downloading checkpoint: step {cp.step_number}")

        for file_id in cp.result_files:
            file_obj = client.files.retrieve(file_id)
            content = client.files.content(file_id)
            path = os.path.join(cp_dir, os.path.basename(file_obj.filename))
            content.write_to_file(path)
            print(f"  Saved: {path}")

    return checkpoints


def test_finetuned_model(model_name: str, prompt: str):
    """Test inference with the fine-tuned model."""
    response = client.chat.completions.create(
        model=model_name,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.7,
        max_tokens=512,
    )
    return response.choices[0].message.content


def compare_base_vs_finetuned(base_model: str, finetuned_model: str, prompts: list[str]):
    """Compare base model vs fine-tuned model on the same prompts."""
    print("=" * 60)
    print("BASE vs FINE-TUNED COMPARISON")
    print("=" * 60)

    for prompt in prompts:
        print(f"\nPrompt: {prompt}")
        print(f"\n--- Base ({base_model}) ---")
        base_response = test_finetuned_model(base_model, prompt)
        print(base_response[:300])

        print(f"\n--- Fine-tuned ({finetuned_model}) ---")
        ft_response = test_finetuned_model(finetuned_model, prompt)
        print(ft_response[:300])

        print("-" * 40)


if __name__ == "__main__":
    print("=== Nebius Fine-Tuning Pipeline ===\n")

    # Step 1: Generate sample data (replace with real data)
    training_file = generate_sample_data("training.jsonl")

    # Step 2: Upload
    training_id = upload_dataset(training_file)

    # Step 3: Start fine-tuning
    job = start_finetune(
        training_file_id=training_id,
        model="meta-llama/Llama-3.1-8B-Instruct",
        suffix="evolved26-hackathon",
        epochs=3,
        use_lora=True,
    )

    # Step 4: Monitor
    completed_job = monitor_job(job.id)

    # Step 5: Download checkpoints
    if completed_job.status == "succeeded":
        download_checkpoints(completed_job.id)

        # Step 6: Compare base vs fine-tuned
        # The fine-tuned model name is typically: {model}:{suffix}
        compare_base_vs_finetuned(
            base_model="meta-llama/Llama-3.1-8B-Instruct",
            finetuned_model=completed_job.fine_tuned_model,  # auto-generated name
            prompts=[
                "What is the STOP technique for rumination?",
                "How does HRV relate to anxiety?",
                "Explain metacognitive therapy in simple terms.",
            ],
        )
