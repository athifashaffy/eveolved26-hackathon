"""
Nebius Token Factory — Inference Examples
Ready-to-run script for the hackathon.

Setup:
  pip install openai
  export NEBIUS_API_KEY=<your_key>
"""

import os
from openai import OpenAI

client = OpenAI(
    base_url="https://api.tokenfactory.nebius.com/v1/",
    api_key=os.environ["NEBIUS_API_KEY"],
)


# --- 1. Basic Chat Completion ---
def chat(prompt: str, system: str = "You are a helpful assistant.", model: str = "meta-llama/Llama-3.3-70B-Instruct"):
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": prompt},
        ],
        temperature=0.7,
        max_tokens=1024,
    )
    return response.choices[0].message.content


# --- 2. Streaming Chat ---
def chat_stream(prompt: str, model: str = "meta-llama/Llama-3.3-70B-Instruct"):
    stream = client.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": prompt}],
        stream=True,
    )
    full_response = ""
    for chunk in stream:
        if chunk.choices[0].delta.content:
            content = chunk.choices[0].delta.content
            print(content, end="", flush=True)
            full_response += content
    print()
    return full_response


# --- 3. Structured JSON Output ---
def structured_output(prompt: str, model: str = "meta-llama/Llama-3.3-70B-Instruct"):
    response = client.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": prompt}],
        response_format={"type": "json_object"},
    )
    return response.choices[0].message.content


# --- 4. Embeddings ---
def embed(text: str):
    """Generate embeddings. Check available embedding models first."""
    response = client.embeddings.create(
        model="BAAI/bge-en-icl",  # verify model name
        input=text,
    )
    return response.data[0].embedding


# --- 5. List Available Models ---
def list_models():
    models = client.models.list()
    for m in models.data:
        print(f"  {m.id}")
    return models


# --- 6. Compare Models ---
def compare_models(prompt: str, models: list[str]):
    """Run the same prompt through multiple models and compare."""
    results = {}
    for model in models:
        print(f"\n--- {model} ---")
        response = chat(prompt, model=model)
        results[model] = response
        print(response[:200] + "..." if len(response) > 200 else response)
    return results


if __name__ == "__main__":
    # Quick test
    print("=== Testing Nebius Token Factory ===\n")

    print("1. Listing available models...")
    list_models()

    print("\n2. Basic chat...")
    result = chat("What is heart rate variability and why does it matter for mental health?")
    print(result)

    print("\n3. Streaming...")
    chat_stream("Explain the STOP technique for rumination in 3 sentences.")

    print("\n4. Model comparison...")
    compare_models(
        "What is the relationship between sleep quality and depression?",
        [
            "meta-llama/Llama-3.3-70B-Instruct",
            "deepseek-ai/DeepSeek-V3-0324",
        ],
    )
