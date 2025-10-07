# 🧰 n8n Workflow Security Audit & JSON Validation Guide  
**Before Importing or Using Workflows in Production**

---

## 📘 Overview
n8n workflows are stored in JSON format.  
While they make it easy to share automation setups, **workflows from unknown or untrusted sources can be dangerous** — they may contain hidden nodes, malicious code, or unsafe webhooks.

This guide explains how to **inspect, sanitize, and validate n8n workflow JSON files** before importing them into production.

---

## ⚠️ Common Risks
| Risk Type | Description | Example |
|------------|--------------|----------|
| 🔒 Credential leakage | Shared credentials or embedded secrets | API keys, passwords, tokens |
| 🌐 Malicious HTTP calls | Nodes sending data to external endpoints | Suspicious URLs or webhook traps |
| 💻 Code execution | Function or Execute Command nodes running JS or system commands | `Function`, `FunctionItem`, `ExecuteCommand` |
| 🧩 Hidden payloads | Encoded or obfuscated data in node parameters | Base64 or hex blobs |
| 📡 Webhook hijacking | Imported public webhook URLs | Unknown inbound webhooks |

---

## 🧾 Step 1 — Initial Offline Inspection

### 1. Open the JSON
Use a viewer such as:
- VS Code (`Format Document`)
- [jsonlint.com](https://jsonlint.com)
- [jsonviewer.stack.hu](https://jsonviewer.stack.hu)

### 2. Search for suspicious keywords
Run:
```bash
grep -Ei "token|secret|password|api_key|apikey|webhook|callback|exec|ssh|command|spawn|child_process" workflow.json
