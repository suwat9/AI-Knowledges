# n8n MITM Check — checklist + ready-to-use workflow

> Purpose: detect and help diagnose possible Man-in-the-Middle (MITM) interception or modification of JSON payloads sent/received by n8n workflows.

---

## Contents

1. Overview
2. Quick prerequisites
3. How it works (concept)
4. Step-by-step instructions
5. n8n workflow (instructions + node code snippets)
6. Command-line checks (openssl, tcpdump, arp)
7. What to do if you detect interception
8. Appendix: sample payload and hash comparison

---

## 1. Overview
This document contains a practical approach to detect whether JSON payloads in your n8n workflows are being intercepted or modified in transit. It provides:

- A short checklist you can follow quickly.
- An n8n workflow you can build that computes a hash of your outgoing JSON, sends it with the request, and optionally verifies it on the server side.
- Useful commands (openssl, tcpdump, arp, dig, traceroute) you can run to inspect network/TLS properties.

> Important: This workflow helps detect payload modifications but cannot by itself prove the presence of a full MITM infrastructure (e.g., corporate TLS proxy presenting a valid-looking cert). Use it together with TLS / cert / network checks below.

---

## 2. Quick prerequisites

- Access to your n8n editor (self-hosted or cloud).
- Ability to edit and execute workflows (create nodes).
- Terminal access for `openssl`, `tcpdump`, `arp`, `dig`, `traceroute` (optional but recommended).
- If possible, access to the server API you're calling so you can compare received hash vs sent hash.

---

## 3. How it works (concept)

1. Compute a deterministic hash (SHA-256) of the JSON payload just before sending.
2. Send the payload to the target API and include the hash in a header (e.g. `X-Payload-Hash`) or in a JSON field.
3. On the receiving server (or a trusted interceptor), compute the SHA-256 of the received JSON and compare it to the provided hash.
4. If the hashes differ, the payload was modified in transit (or the sender/receiver computed the hash differently).

This doesn't prove who modified it, but it's a reliable detection of modification.

---

## 4. Step-by-step instructions

1. Create a new workflow in n8n.
2. Add a **Set** node (name: `Payload`) and paste your example JSON into a single field (or create fields that match your data).
3. Add a **Function** node (name: `ComputeHash`) that computes SHA-256 of the JSON and outputs both `json` and `hash`.
4. Add an **HTTP Request** node (name: `SendRequest`) that sends the JSON to your API. Add header `X-Payload-Hash` with the computed hash from `ComputeHash` node.
5. Optionally, add another **HTTP Request** node that fetches the server-side recorded hash for comparison or implement server-side verification.
6. Execute workflow and inspect execution data for the JSON and for the hash values.

---

## 5. n8n workflow: nodes and code

### Node: Payload (Set)
Add a single field `payload` (type: JSON) and paste your JSON. Example value (as JSON):

```json
{
  "user": "alice",
  "amount": 125.5,
  "currency": "USD",
  "items": [
    {"id": "A1","qty": 2},
    {"id": "B3","qty": 1}
  ]
}
```

### Node: ComputeHash (Function)
- Purpose: compute the SHA-256 hash of the canonicalized JSON string.
- Use deterministic stringification: sort object keys so both sides compute the same string for identical data.

Paste this code into the Function node:

```javascript
const crypto = require('crypto');

// Helper: stable stringify (sorts object keys recursively)
function stableStringify(obj) {
  if (obj === null || typeof obj !== 'object') return JSON.stringify(obj);
  if (Array.isArray(obj)) return '[' + obj.map(stableStringify).join(',') + ']';
  const keys = Object.keys(obj).sort();
  return '{' + keys.map(k => JSON.stringify(k) + ':' + stableStringify(obj[k])).join(',') + '}';
}

const input = $json.payload || $input.item.json.payload || $input.all()[0].json.payload;
const canonical = stableStringify(input);
const hash = crypto.createHash('sha256').update(canonical).digest('hex');

return [{ json: { payload: input, canonicalString: canonical, payloadHash: hash } }];
```

> The `stableStringify` function sorts keys to avoid differences due to key ordering which would otherwise change the hash.

### Node: SendRequest (HTTP Request)
- Method: POST (or the method your API expects)
- URL: `https://yourapi.example/endpoint`
- Authentication: as required (use n8n credentials)
- Body Content Type: `JSON` and set body to the `payload` from `ComputeHash` node
- Headers: Add header `X-Payload-Hash` with value `{{$node["ComputeHash"].json["payloadHash"]}}`

Example header:
```
X-Payload-Hash: {{$node["ComputeHash"].json["payloadHash"]}}
```

### Optional: RetrieveServerHash (HTTP Request)
If your server can return the last-received hash for this message (or you can implement a debug endpoint), call it and compare server-side hash to the hash you computed.

### Optional: Compare (Function)
Add a Function node to compare `{{$node["ComputeHash"].json["payloadHash"]}}` vs `{{$node["RetrieveServerHash"].json["receivedHash"]}}` and throw an error or set a warning field if they differ.

---

## 6. Command-line checks you should run

### TLS / certificate check
```bash
openssl s_client -connect yourapi.example:443 -servername yourapi.example -showcerts
```
Look for issuer, validity dates, and certificate chain. If the issuer is an internal proxy CA you didn't expect, investigate.

### Get fingerprint (SHA-256)
```bash
echo | openssl s_client -connect yourapi.example:443 -servername yourapi.example 2>/dev/null \
  | openssl x509 -noout -fingerprint -sha256
```

### Network capture (see if a local proxy is decrypting)
```bash
sudo tcpdump -i any -n -s 0 -w n8n_capture.pcap 'tcp port 443'
# reproduce the request, then open capture in Wireshark
```

TLS is encrypted; you will *not* see payload JSON unless a MITM terminates TLS and re-encrypts using a different cert (which you can detect by certificate changes).

### ARP / local checks
```bash
arp -a
sudo arping -c 4 <gateway-ip>
```
Look for duplicated MACs or unexpected responses.

### DNS / routing
```bash
dig +short yourapi.example @1.1.1.1
dig +short yourapi.example @8.8.8.8
traceroute yourapi.example
```
If DNS returns unexpected IPs or traceroute shows weird early hops, investigate.

---

## 7. What to do if you detect interception

1. Immediately stop using the suspect network. Use a known-good network (mobile hotspot) to verify.  
2. Rotate secrets and API tokens that may have been exposed.  
3. Remove unknown root CA certs from devices if you can confirm they are unauthorized (coordinate with IT).  
4. Use mTLS or certificate pinning for critical services.  
5. Notify your security/IT team and provide evidence (hash mismatches, cert screenshots, pcap captures).

---

## 8. Appendix: sample payload and hash comparison (example)

**Canonical payload (sorted keys):**

```
{"amount":125.5,"currency":"USD","items":[{"id":"A1","qty":2},{"id":"B3","qty":1}],"user":"alice"}
```

**SHA-256 hash (hex):**

```
3f6a9a5b5f2e3c6a8b4f1c2d0e6a8b9d4c3f2a1b6c7d8e9f0a1b2c3d4e5f6a7
```

> (The hex above is an example — compute with the Function node for your real payload.)

---

### End of document

If you want, I can also:
- Produce a downloadable `.md` file in the workspace, or
- Create an actual n8n workflow JSON export that you can import directly (I can include that here as a follow-up).

