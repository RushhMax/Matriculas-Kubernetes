#!/usr/bin/env python3
"""Copy the local Academy profile to GitHub Secrets without printing credentials."""
import json
import os
from pathlib import Path
import shutil
import subprocess


def main():
    repository = 'RushhMax/Matriculas-Kubernetes'
    gh = shutil.which('gh')
    aws = shutil.which('aws') or str(Path.home() / '.local/bin/aws')
    if not gh:
        raise SystemExit('Instala GitHub CLI (gh) y ejecuta gh auth login antes de configurar secrets.')
    auth = subprocess.run([gh, 'auth', 'status'], capture_output=True)
    if auth.returncode:
        raise SystemExit('Primero ejecuta gh auth login con tu cuenta de GitHub.')
    environment = os.environ.copy()
    for key in ('AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_SESSION_TOKEN'):
        environment.pop(key, None)
    identity = subprocess.run([
        aws, 'sts', 'get-caller-identity', '--profile', 'unsa-lab',
        '--region', 'us-east-1', '--query', 'Account', '--output', 'text',
    ], env=environment, capture_output=True, text=True)
    if identity.returncode or identity.stdout.strip() != '455290382075':
        raise SystemExit('Renueva el perfil unsa-lab y verifica la cuenta del equipo primero.')
    exported = subprocess.run([
        aws, 'configure', 'export-credentials', '--profile', 'unsa-lab', '--format', 'process',
    ], env=environment, capture_output=True, text=True)
    if exported.returncode:
        raise SystemExit('No se pudieron cargar las credenciales locales. No se actualizaron secrets.')
    values = json.loads(exported.stdout)
    mapping = {
        'AWS_ACCESS_KEY_ID': 'AccessKeyId',
        'AWS_SECRET_ACCESS_KEY': 'SecretAccessKey',
        'AWS_SESSION_TOKEN': 'SessionToken',
    }
    if not all(values.get(key) for key in mapping.values()):
        raise SystemExit('El perfil no contiene las tres credenciales temporales. No se actualizaron secrets.')
    for secret, field in mapping.items():
        result = subprocess.run([
            gh, 'secret', 'set', secret, '--repo', repository,
        ], input=values[field], text=True, capture_output=True)
        if result.returncode:
            raise SystemExit(f'No se pudo actualizar {secret}. Verifica permisos sobre los secrets de {repository} y repite el proceso completo.')
        print(f'{secret}: actualizado (valor oculto).')
    print('Renueva los tres secrets cuando caduque la sesión de Academy.')


if __name__ == '__main__':
    main()
