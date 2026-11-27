from pathlib import Path
from time import perf_counter

import pandas as pd

from src import reduction_sources as rs


_RACINE_PROJET = Path(__file__).resolve().parent.parent
_DOSSIER_INTERIM = _RACINE_PROJET / 'data' / 'interim'
_DOSSIER_PROCESSED = _RACINE_PROJET / 'data' / 'processed'
_DOSSIER_SUPPLEMENTS = _RACINE_PROJET / 'data' / 'supplements'

CHEMIN_CATALOGUE = _DOSSIER_PROCESSED / 'catalogue.csv'
CHEMIN_SUPPLEMENT_PRINCIPALS = _DOSSIER_SUPPLEMENTS / 'title.principals.csv'
CHEMIN_NAME_BASICS = _DOSSIER_INTERIM / 'name.basics.csv'
CHEMIN_TITLE_AKAS = _DOSSIER_INTERIM / 'title.akas.csv'
CHEMIN_TITLE_BASICS = _DOSSIER_INTERIM / 'title.basics.csv'
CHEMIN_TITLE_PRINCIPALS = _DOSSIER_INTERIM / 'title.principals.csv'
CHEMIN_TITLE_RATINGS = _DOSSIER_INTERIM / 'title.ratings.csv'
CHEMIN_TMDB_DATASET = _DOSSIER_INTERIM / 'TMDB_movie_dataset_v11.csv'


def exporter_sources_reduites():
    debut = perf_counter()

    print("=== Export des sources réduites ===")

    _DOSSIER_INTERIM.mkdir(parents=True, exist_ok=True)

    print("\nChargement du catalogue…")
    catalogue = pd.read_csv(
        CHEMIN_CATALOGUE,
        dtype='string',
        usecols=['tconst', 'tmdb_id'],
    )

    ids_imdb = catalogue['tconst'].dropna().unique()
    ids_tmdb = catalogue['tmdb_id'].dropna().unique()

    print(f"[OK] {len(catalogue):,} films chargés")

    print("\n[1/6] IMDb — Title Ratings")
    title_ratings = rs.reduire_title_ratings(ids_imdb)
    title_ratings.to_csv(CHEMIN_TITLE_RATINGS, index=False)
    print(f"[OK] Export : {CHEMIN_TITLE_RATINGS.name}")

    print("\n[2/6] IMDb — Title Basics")
    title_basics = rs.reduire_title_basics(ids_imdb)
    title_basics.to_csv(CHEMIN_TITLE_BASICS, index=False)
    print(f"[OK] Export : {CHEMIN_TITLE_BASICS.name}")

    print("\n[3/6] IMDb — Title Akas")
    title_akas = rs.reduire_title_akas(ids_imdb)
    title_akas.to_csv(CHEMIN_TITLE_AKAS, index=False)
    print(f"[OK] Export : {CHEMIN_TITLE_AKAS.name}")

    print("\n[4/6] TMDB — Movie Dataset")
    tmdb_dataset = rs.reduire_tmdb_dataset(ids_imdb, ids_tmdb)
    tmdb_dataset.to_csv(CHEMIN_TMDB_DATASET, index=False)
    print(f"[OK] Export : {CHEMIN_TMDB_DATASET.name}")

    print("\n[5/6] IMDb — Title Principals")
    title_principals = rs.reduire_title_principals(ids_imdb)
    title_principals.to_csv(CHEMIN_TITLE_PRINCIPALS, index=False)
    print(f"[OK] Export : {CHEMIN_TITLE_PRINCIPALS.name}")

    print("\n[6/6] IMDb — Name Basics")
    ids_personnes = title_principals['nconst']

    if CHEMIN_SUPPLEMENT_PRINCIPALS.is_file():
        supplement_principals = pd.read_csv(
            CHEMIN_SUPPLEMENT_PRINCIPALS,
            dtype='string',
            usecols=['tconst', 'nconst'],
        )
        ids_supplement = supplement_principals.loc[
            supplement_principals['tconst'].isin(ids_imdb),
            'nconst',
        ]
        ids_personnes = pd.concat([ids_personnes, ids_supplement])
        print('[OK] Identifiants du supplément pris en compte')

    ids_personnes = ids_personnes.dropna().unique()
    name_basics = rs.reduire_name_basics(ids_personnes)
    name_basics.to_csv(CHEMIN_NAME_BASICS, index=False)
    print(f"[OK] Export : {CHEMIN_NAME_BASICS.name}")

    print("\n=== Export des sources réduites terminé ===")
    print(f"Temps total : {perf_counter() - debut:.1f} s")


if __name__ == '__main__':
    exporter_sources_reduites()

