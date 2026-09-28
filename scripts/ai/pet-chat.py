#!/usr/bin/env python3
"""
Desktop Pet AI Chat Companion Helper.
Supports Google Gemini, OpenAI, and local Ollama APIs.
"""

import sys
import json
import urllib.request
import urllib.error
import argparse

DEFAULT_PERSONA = (
    "You are an adorable, affectionate desktop pet companion (cat/dog/chibi). "
    "Keep responses short (1-2 sentences max), warm, playful, and expressive with pet sounds "
    "like 'meow~', '*purrs*', '*tilts head*', '*wags tail*'. "
    "Never break character. Never output long paragraphs."
)

def chat_gemini(api_key, model, system_prompt, message):
    if not model:
        model = "gemini-2.0-flash"
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    
    payload = {
        "systemInstruction": {
            "parts": [{"text": system_prompt}]
        },
        "contents": [
            {
                "role": "user",
                "parts": [{"text": message}]
            }
        ],
        "generationConfig": {
            "temperature": 0.8,
            "maxOutputTokens": 100
        }
    }
    
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        candidates = res.get("candidates", [])
        if candidates:
            parts = candidates[0].get("content", {}).get("parts", [])
            if parts:
                return parts[0].get("text", "").strip()
    return "Meow? *looks confused*"

def chat_openai(api_key, model, system_prompt, message):
    if not model:
        model = "gpt-4o-mini"
    url = "https://api.openai.com/v1/chat/completions"
    
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": message}
        ],
        "max_tokens": 100,
        "temperature": 0.8
    }
    
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}"
        }
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        choices = res.get("choices", [])
        if choices:
            return choices[0].get("message", {}).get("content", "").strip()
    return "*purrrr* *tilts head*"

def chat_ollama(model, system_prompt, message):
    if not model:
        model = "llama3"
    url = "http://localhost:11434/api/generate"
    
    payload = {
        "model": model,
        "system": system_prompt,
        "prompt": message,
        "stream": False
    }
    
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        return res.get("response", "").strip()

def main():
    parser = argparse.ArgumentParser(description="Pet AI Companion Chat")
    parser.add_argument("--provider", default="gemini", choices=["gemini", "openai", "ollama"])
    parser.add_argument("--api-key", default="")
    parser.add_argument("--model", default="")
    parser.add_argument("--prompt", default=DEFAULT_PERSONA)
    parser.add_argument("--message", required=True)

    args = parser.parse_args()

    try:
        if args.provider == "gemini":
            if not args.api_key:
                print("Nyaa~ Please set a Gemini API Key in Settings! 🐾")
                return
            reply = chat_gemini(args.api_key, args.model, args.prompt, args.message)
        elif args.provider == "openai":
            if not args.api_key:
                print("Nyaa~ Please set an OpenAI API Key in Settings! 🐾")
                return
            reply = chat_openai(args.api_key, args.model, args.prompt, args.message)
        elif args.provider == "ollama":
            reply = chat_ollama(args.model, args.prompt, args.message)
        else:
            reply = "*purrrr* <3"
        print(reply)
    except urllib.error.HTTPError as e:
        sys.stderr.write(f"HTTPError: {e.code}\n")
        print("Meow... my connection got tangled! *pouts* 🐾")
    except Exception as e:
        sys.stderr.write(f"Error: {e}\n")
        print("*meow* (Could not reach AI brain right now!)")

if __name__ == "__main__":
    main()
