from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
files = sorted((root / ".github").glob("**/*.yml")) + sorted((root / ".github").glob("**/*.yaml"))
patterns = {
    "Terraform mutation": re.compile(r"\bterraform\s+(?:apply|destroy|import|taint|untaint)\b", re.IGNORECASE),
    "Terraform state mutation": re.compile(r"\bterraform\s+state\s+(?:mv|rm|push|replace-provider)\b", re.IGNORECASE),
    "Terraform wrapper mutation": re.compile(r"\btf\.(?:sh|ps1)\b[^\r\n]*(?:apply|destroy)\b", re.IGNORECASE),
    "Deployment action": re.compile(r"\bazure/(?:arm-deploy|webapps-deploy)@", re.IGNORECASE),
    "Azure CLI deployment": re.compile(r"\baz\s+deployment\b", re.IGNORECASE),
    "Azure CLI mutation": re.compile(r"\baz\s+[^\r\n]+\s+(?:create|delete|update)\b", re.IGNORECASE),
    "Azure PowerShell mutation": re.compile(r"\b(?:New|Set|Update|Remove)-Az[A-Za-z0-9]+\b", re.IGNORECASE),
    "Kubernetes mutation": re.compile(r"\bkubectl\s+(?:apply|create|delete|patch|replace|scale|set)\b", re.IGNORECASE),
    "Helm mutation": re.compile(r"\bhelm\s+(?:install|upgrade|uninstall|rollback)\b", re.IGNORECASE),
    "Pulumi mutation": re.compile(r"\bpulumi\s+(?:up|destroy)\b", re.IGNORECASE),
    "Deployment phase input": re.compile(r"\baction:\s*(?:apply|destroy)\b", re.IGNORECASE),
}

failures = []
for path in files:
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        for name, pattern in patterns.items():
            if pattern.search(line):
                failures.append(f"{path.relative_to(root)}:{line_number}: {name}: {line.strip()}")

if failures:
    print("Deployment-capable commands are forbidden in CI configuration:")
    print("\n".join(failures))
    sys.exit(1)

print(f"Validated {len(files)} pipeline files: no deployment-capable commands found.")
