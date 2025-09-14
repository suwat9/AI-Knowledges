Add them to your shell config file:
```shell
nano ~/.bashrc
```
At the bottom, add:
```bash
export N8N_PORT=5678
export N8N_EDITOR_BASE_URL="http://localhost:5678"
export N8N_HOST="0.0.0.0"
```
Save & reload:
```bash
source ~/.bashrc
```
