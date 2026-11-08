#!/usr/bin/env python3
"""Render or deploy one ECR release after Persona 3 has prepared the AWS overlay."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile
import time
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', required=True, help='Full Git commit SHA published to ECR')
    parser.add_argument('--deploy', action='store_true', help='Apply to the current kubectl context')
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9a-f]{40}', args.tag):
        parser.error('--tag must be the full Git commit SHA')
    root = Path(__file__).resolve().parent.parent
    registry = '455290382075.dkr.ecr.us-east-1.amazonaws.com'
    # A sibling overlay keeps the source files unchanged and pins both images.
    with tempfile.TemporaryDirectory(prefix='.release-', dir=root / 'k8s/overlays') as temporary:
        release = Path(temporary)
        (release / 'kustomization.yaml').write_text(json.dumps({
            'apiVersion': 'kustomize.config.k8s.io/v1beta1', 'kind': 'Kustomization',
            'resources': ['../aws'],
            'images': [
                {'name': f'{registry}/unsa-matricula-{component}', 'newTag': args.tag}
                for component in ('backend', 'frontend')
            ],
        }))
        result = subprocess.run(['kubectl', 'kustomize', str(release)], capture_output=True, text=True)
        if result.returncode:
            raise SystemExit('No se pudo generar el overlay AWS. Revisa la base y los parches con Persona 3:\n' + result.stderr)
        rendered = result.stdout
        for component in ('backend', 'frontend'):
            if f'{registry}/unsa-matricula-{component}:{args.tag}' not in rendered:
                raise SystemExit(f'El overlay no fijó la imagen ECR de {component} al SHA solicitado.')
        if not args.deploy:
            print(rendered, end='')
            return
        context = subprocess.check_output(['kubectl', 'config', 'current-context'], text=True).strip()
        if not context.endswith(':cluster/unsa-matricula-dev-cluster') or ':455290382075:' not in context:
            raise SystemExit('El contexto actual no corresponde al EKS esperado. Actualiza el kubeconfig primero.')
        subprocess.run(['kubectl', 'apply', '-f', '-'], input=rendered, text=True, check=True)
    for component in ('backend', 'frontend'):
        subprocess.run(['kubectl', '-n', 'unsa-matricula', 'rollout', 'status', f'deployment/{component}', '--timeout=180s'], check=True)
    forward = subprocess.Popen([
        'kubectl', '-n', 'unsa-matricula', 'port-forward', 'svc/frontend-service', '18080:80',
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for attempt in range(30):
            if forward.poll() is not None:
                raise SystemExit('No se pudo abrir el túnel para el smoke test. Revisa el puerto local 18080.')
            try:
                with urllib.request.urlopen('http://127.0.0.1:18080/api/ready', timeout=3) as response:
                    status = json.load(response)
                    if status.get('status') != 'ready' or status.get('version') != args.tag:
                        raise ValueError('Backend no preparado')
                with urllib.request.urlopen('http://127.0.0.1:18080/api/courses', timeout=3) as response:
                    if not isinstance(json.load(response).get('data'), list):
                        raise ValueError('Respuesta de cursos inválida')
                print('Smoke test frontend → API → PostgreSQL: OK')
                break
            except (OSError, ValueError):
                if attempt == 29:
                    raise
                time.sleep(2)
    finally:
        forward.terminate()
        forward.wait(timeout=10)


if __name__ == '__main__':
    main()
