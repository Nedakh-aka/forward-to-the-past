"""Charge et réduit les sources IMDb et TMDB sans les exporter."""

import csv
from pathlib import Path
from time import perf_counter

import pandas as pd

_RACINE_PROJET = Path(__file__).resolve().parent.parent
_DOSSIER_RAW = _RACINE_PROJET / 'data' / 'raw'

CHEMIN_NAME_BASICS = _DOSSIER_RAW / 'name.basics.tsv.gz'
CHEMIN_TITLE_AKAS = _DOSSIER_RAW / 'title.akas.tsv.gz'
CHEMIN_TITLE_BASICS = _DOSSIER_RAW / 'title.basics.tsv.gz'
CHEMIN_TITLE_PRINCIPALS = _DOSSIER_RAW / 'title.principals.tsv.gz'
CHEMIN_TITLE_RATINGS = _DOSSIER_RAW / 'title.ratings.tsv.gz'
CHEMIN_TMDB_DATASET = _DOSSIER_RAW / 'TMDB_movie_dataset_v11.csv'

TAILLE_BLOC = 200_000
FREQUENCE_PROGRESSION = 10

OPTIONS_IMDB = {
    'sep': '\t',
    'compression': 'gzip',
    'quoting': csv.QUOTE_NONE,
    'dtype': 'string',
    'na_values': [r'\N'],
}

OPTIONS_TMDB = {
    'dtype': 'string',
    'na_values': [''],
}


def lire_par_blocs(
    adresse,
    retenir,
    *,
    taille_bloc,
    frequence_progression,
    **options,
):
    """Lit une source par blocs et conserve les lignes sélectionnées par retenir."""
    blocs_retenus = []
    total_lu = 0
    total_retenu = 0
    debut = perf_counter()

    with pd.read_csv(
        adresse,
        chunksize=taille_bloc,
        **options,
    ) as lecteur:
        for numero, bloc in enumerate(lecteur, start=1):
            total_lu += len(bloc)
            extrait = bloc.loc[retenir(bloc)].copy()

            if not extrait.empty:
                blocs_retenus.append(extrait)
                total_retenu += len(extrait)

            if numero % frequence_progression == 0:
                print(
                    f"  Bloc {numero} | {total_lu:,} lignes lues | "
                    f"{total_retenu:,} retenues | {perf_counter() - debut:.1f} s",
                    flush=True,
                )

    print('  Assemblage des blocs retenus…', flush=True)
    if blocs_retenus:
        table = pd.concat(blocs_retenus, ignore_index=True)
    else:
        # Conserver le schéma de la source même si aucune ligne n'est retenue.
        table = pd.read_csv(adresse, nrows=0, **options)

    print(
        f"  [OK] {total_lu:,} lignes lues | {len(table):,} retenues | "
        f"{perf_counter() - debut:.1f} s",
        flush=True,
    )
    return table


def reduire_name_basics(ids_personnes):
    return lire_par_blocs(
        CHEMIN_NAME_BASICS,
        lambda bloc: bloc['nconst'].isin(ids_personnes),
        taille_bloc=TAILLE_BLOC,
        frequence_progression=FREQUENCE_PROGRESSION,
        **OPTIONS_IMDB,
    )


def reduire_title_akas(ids_films):
    return lire_par_blocs(
        CHEMIN_TITLE_AKAS,
        lambda bloc: bloc['titleId'].isin(ids_films),
        taille_bloc=TAILLE_BLOC,
        frequence_progression=FREQUENCE_PROGRESSION,
        **OPTIONS_IMDB,
    )


def reduire_title_basics(ids_films):
    return lire_par_blocs(
        CHEMIN_TITLE_BASICS,
        lambda bloc: bloc['tconst'].isin(ids_films),
        taille_bloc=TAILLE_BLOC,
        frequence_progression=FREQUENCE_PROGRESSION,
        **OPTIONS_IMDB,
    )


def reduire_title_principals(ids_films):
    return lire_par_blocs(
        CHEMIN_TITLE_PRINCIPALS,
        lambda bloc: bloc['tconst'].isin(ids_films),
        taille_bloc=TAILLE_BLOC,
        frequence_progression=FREQUENCE_PROGRESSION,
        **OPTIONS_IMDB,
    )


def reduire_title_ratings(ids_films):
    return lire_par_blocs(
        CHEMIN_TITLE_RATINGS,
        lambda bloc: bloc['tconst'].isin(ids_films),
        taille_bloc=TAILLE_BLOC,
        frequence_progression=FREQUENCE_PROGRESSION,
        **OPTIONS_IMDB,
    )


def reduire_tmdb_dataset(ids_imdb, ids_tmdb):
    """Retient les fiches correspondant à un identifiant IMDb ou TMDB."""
    return lire_par_blocs(
        CHEMIN_TMDB_DATASET,
        # Inclure les fiches TMDB sans identifiant IMDb mais présentes au catalogue.
        lambda bloc: (
            bloc['imdb_id'].isin(ids_imdb)
            | bloc['id'].isin(ids_tmdb)
        ),
        taille_bloc=TAILLE_BLOC,
        frequence_progression=FREQUENCE_PROGRESSION,
        **OPTIONS_TMDB,
    )

