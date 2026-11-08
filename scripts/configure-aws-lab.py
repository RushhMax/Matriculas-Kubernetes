#!/usr/bin/env python3
"""Store temporary Academy credentials in a separate local profile, without echoing them."""
import configparser
import getpass
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    print('Activa Start Lab y abre AWS Details > AWS CLI > Show.')
    print('Pega SOLO el valor de cada credencial, sin export ni comillas. No se mostrará.')
    credentials = {
        key: getpass.getpass(f'{key}: ').strip()
        for key in ('aws_access_key_id', 'aws_secret_access_key', 'aws_session_token')
    }
    if not all(credentials.values()):
        raise SystemExit('Falta una credencial. No se guardó ningún cambio.')
    destination = Path.home() / '.aws' / 'credentials'
    destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    config = configparser.RawConfigParser()
    config.read(destination)
    config['unsa-lab'] = credentials | {'region': 'us-east-1'}
    descriptor, temporary = tempfile.mkstemp(dir=destination.parent)
    try:
        with os.fdopen(descriptor, 'w') as stream:
            config.write(stream)
        os.chmod(temporary, 0o600)
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print('Perfil unsa-lab guardado. Los otros perfiles se conservaron.')
    aws = shutil.which('aws') or str(Path.home() / '.local/bin/aws')
    environment = os.environ.copy()
    for key in ('AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_SESSION_TOKEN'):
        environment.pop(key, None)
    result = subprocess.run([
        aws, 'sts', 'get-caller-identity', '--profile', 'unsa-lab',
        '--region', 'us-east-1', '--query', 'Account', '--output', 'text',
    ], env=environment, capture_output=True, text=True)
    if result.returncode:
        raise SystemExit('No se pudo validar el perfil. Comprueba la sesión y vuelve a ejecutar este asistente.')
    account = result.stdout.strip()
    if account != '455290382075':
        raise SystemExit(f'Cuenta detectada: {account}. No coincide con la cuenta del equipo (455290382075).')
    print(f'Conexión verificada con la cuenta del equipo: {account}.')


if __name__ == '__main__':
    main()
