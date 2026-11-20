import pandas as pd

_PATH_RAW = "data/raw/"
_PATH_INTERIM = "data/interim/"

def creer_principals_catalogue(df_catalogue):
    lien = _PATH_RAW + "title.principals.tsv.gz"
    df = pd.read_csv(lien, sep="\t", compression='gzip', low_memory=False, na_values="\\N")

    print(df.shape[0])
    masque = df['tconst'].isin(df_catalogue['tconst'])
    df = df[masque]
    print(df.shape[0])

    lien = _PATH_INTERIM + "title.principals.csv"
    df.to_csv(lien, encoding='utf-8', sep=',', index=False)


def creer_name_basics():
    lien = _PATH_INTERIM + "title.principals.csv"
    df_principals = pd.read_csv(lien, sep=',')

    lien = _PATH_RAW + "name.basics.tsv.gz"
    df = pd.read_csv(lien, sep="\t", compression='gzip', low_memory=False, na_values="\\N")

    print(df.shape[0])
    masque = df['nconst'].isin(df_principals['nconst'])
    df = df[masque]
    print(df.shape[0])

    lien = _PATH_INTERIM + "name.basics.csv"
    df.to_csv(lien, encoding='utf-8', sep=',', index=False)


def creer_akas_catalogue(df_catalogue):
    lien = _PATH_RAW + "title.akas.tsv.gz"
    df = pd.read_csv(lien, sep="\t", compression='gzip', low_memory=False, na_values="\\N")

    print(df.shape[0])
    masque = df['titleId'].isin(df_catalogue['tconst'])
    df = df[masque]
    print(df.shape[0])

    lien = _PATH_INTERIM + "title.akas.csv"
    df.to_csv(lien, encoding='utf-8', sep=',', index=False)


def creer_basics_catalogue(df_catalogue):
    lien = _PATH_RAW + "title.basics.tsv.gz"
    df = pd.read_csv(lien, sep="\t", compression='gzip', low_memory=False, na_values="\\N")

    print(df.shape[0])
    masque = df['tconst'].isin(df_catalogue['tconst'])
    df = df[masque]
    print(df.shape[0])

    lien = _PATH_INTERIM + "title.basics.csv"
    df.to_csv(lien, encoding='utf-8', sep=',', index=False)


def creer_rating_catalogue(df_catalogue):
    lien = _PATH_RAW + "title.ratings.tsv.gz"
    df = pd.read_csv(lien, sep="\t", compression='gzip', low_memory=False, na_values="\\N")

    print(df.shape[0])
    masque = df['tconst'].isin(df_catalogue['tconst'])
    df = df[masque]
    print(df.shape[0])

    lien = _PATH_INTERIM + "title.ratings.csv"
    df.to_csv(lien, encoding='utf-8', sep=',', index=False)


def creer_tmdb_catalogue(df_catalogue):
    lien = _PATH_RAW + "TMDB_movie_dataset_v11.csv"
    df = pd.read_csv(lien, sep=",", low_memory=False)


    print(df.shape[0])
    masque = df['imdb_id'].isin(df_catalogue['tconst'])
    df = df[masque]
    print(df.shape[0])
    print(df['imdb_id'].is_unique)

    lien = _PATH_INTERIM + "TMDB_movie_dataset_v11.csv"
    df.to_csv(lien, encoding='utf-8', sep=',', index=False)


print("Chargement catalogue")
df_cat = pd.read_csv("data/processed/dataset_catalogue_filtres.csv")
print("Fin chargement catalogue")

creer_principals_catalogue(df_cat)
creer_name_basics()
creer_akas_catalogue(df_cat)
creer_basics_catalogue(df_cat)
creer_rating_catalogue(df_cat)
creer_tmdb_catalogue(df_cat)