"""Orchestre la création et l'enrichissement du catalogue de films."""

import argparse
import sys
import warnings
from pathlib import Path
from time import perf_counter

import nbformat
from jupyter_client import AsyncKernelManager
from nbclient import NotebookClient

from src import exporter_sources_reduites as esr


_RACINE_PROJET = Path(__file__).resolve().parent
_DOSSIER_NOTEBOOKS = _RACINE_PROJET / 'notebooks'

CHEMIN_CREATION = _DOSSIER_NOTEBOOKS / '01_creation_catalogue.ipynb'
CHEMIN_ENRICHISSEMENT = _DOSSIER_NOTEBOOKS / '02_enrichissement_catalogue.ipynb'
CHEMIN_RESULTAT = _RACINE_PROJET / 'data' / 'processed' / 'dataset_catalogue_filtres.csv'


class NotebookClientVerbeux(NotebookClient):
    """Retransmet les sorties du kernel au terminal dès leur réception."""

    def process_message(self, msg, cell, cell_index):
        if msg['msg_type'] == 'stream':
            contenu = msg['content']

            if contenu['name'] == 'stdout':
                sys.stdout.write(contenu['text'])
                sys.stdout.flush()
            elif contenu['name'] == 'stderr':
                sys.stderr.write(contenu['text'])
                sys.stderr.flush()

        elif msg['msg_type'] in ('display_data', 'execute_result'):
            donnees = msg['content']['data']

            if 'text/plain' in donnees:
                sys.stdout.write(donnees['text/plain'] + '\n')
                sys.stdout.flush()

        return super().process_message(msg, cell, cell_index)


def parametrer_notebook(notebook, parametres: dict[str, bool]) -> None:
    """Modifie les affectations de configuration en mémoire uniquement."""
    occurrences = dict.fromkeys(parametres, 0)

    for cellule in notebook.cells:
        if cellule.cell_type != 'code':
            continue

        lignes_modifiees = []
        for ligne in cellule.source.split('\n'):
            for nom, valeur in parametres.items():
                if ligne.startswith(f'{nom} = '):
                    ligne = f'{nom} = {valeur}'
                    occurrences[nom] += 1
                    break
            lignes_modifiees.append(ligne)

        cellule.source = '\n'.join(lignes_modifiees)

    # Un paramètre absent ou ambigu ne doit pas être ignoré silencieusement.
    for nom, nombre in occurrences.items():
        if nombre != 1:
            raise ValueError(
                f'Paramètre {nom} : une affectation attendue, {nombre} trouvée(s).'
            )
        print(f'  {nom} = {parametres[nom]}', flush=True)


def executer_notebook(chemin: Path, parametres: dict[str, bool]) -> None:
    """Charge, paramètre et exécute un notebook sans modifier son fichier."""
    debut = perf_counter()
    print(f'\nExécution : {chemin.name}', flush=True)

    with chemin.open(encoding='utf-8') as fichier:
        notebook = nbformat.read(fichier, as_version=nbformat.NO_CONVERT)

    parametrer_notebook(notebook, parametres)

    gestionnaire_kernel = AsyncKernelManager(
        kernel_name='python3',
        transport_encryption='required',
    )

    client = NotebookClientVerbeux(
        notebook,
        timeout=None,
        km=gestionnaire_kernel,
        resources={
            'metadata': {
                # Les chemins relatifs des notebooks partent de leur dossier.
                'path': str(chemin.parent.resolve()),
            },
        },
    )

    # Le gestionnaire fourni explicitement doit être arrêté après exécution.
    client.execute(cleanup_kc=True)
    print(f'[OK] {chemin.name} : {perf_counter() - debut:.1f} s', flush=True)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        prog='main.py',
        description='Construit et enrichit le catalogue de films Forward to the Past.',
    )
    parser.add_argument(
        '-i', '--interim',
        action='store_true',
        help='Générer et utiliser les fichiers intermédiaires.',
    )
    parser.add_argument(
        '-f', '--forcer-telechargement',
        action='store_true',
        help='Forcer le téléchargement des sources gérées par le premier notebook.',
    )
    args = parser.parse_args(argv)

    warnings.filterwarnings(
        'ignore',
        message='Proactor event loop does not implement add_reader.*',
        category=RuntimeWarning,
        module=r'zmq\._future',
    )

    debut = perf_counter()
    print('=== Forward to the Past — Construction du catalogue ===', flush=True)
    print(f"Mode : {'interim' if args.interim else 'raw'}", flush=True)

    etape = 'Création du catalogue'
    try:
        print(f'\n[1/3] {etape}', flush=True)
        executer_notebook(CHEMIN_CREATION, {
            'FORCER_TELECHARGEMENT': args.forcer_telechargement,
        })

        etape = 'Export des sources réduites'
        if args.interim:
            print(f'\n[2/3] {etape}', flush=True)
            esr.exporter_sources_reduites()
        else:
            print(f'\n[2/3] {etape} — ignoré (mode raw)', flush=True)

        etape = 'Enrichissement du catalogue'
        print(f'\n[3/3] {etape}', flush=True)
        executer_notebook(CHEMIN_ENRICHISSEMENT, {
            'UTILISER_INTERIM': args.interim,
        })
    except Exception as erreur:
        print(f'\n[ERREUR] {etape} : {erreur}', file=sys.stderr, flush=True)
        return 1
    except KeyboardInterrupt:
        print(f'\n[INTERROMPU] {etape}', file=sys.stderr, flush=True)
        return 130

    print('\n=== Construction du catalogue terminée ===', flush=True)
    print(f'Résultat : {CHEMIN_RESULTAT}', flush=True)
    print(f'Temps total : {perf_counter() - debut:.1f} s', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
