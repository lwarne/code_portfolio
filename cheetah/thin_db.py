"""
Collection of utils to access Redshift data
"""
import hashlib
import json
import os

import pandas as pd
import sqlalchemy


class ThinDB:
    """A thin wrapper around sqlalchemy and local cache for SQL queries.

    Assumes environment variable DATA_DIR points to cache directory and
    DB_CREDS points to json containing login information.
    """

    def __init__(self):
        assert ('DATA_DIR' in os.environ), 'Data directory not specified'
        assert ('DB_CREDS' in os.environ), 'DB Credentials not found'
        self.data_dir = os.environ['DATA_DIR']
        with open(os.environ['DB_CREDS']) as f:
            self.conf = json.load(f)

    def fetch(self, query, cache=True, **kwargs):
        """Fetches rows from Redshift, or local cache if available.

        Retrieves rows pertaining to the given SQL query.

        Args:
            query: a SQL query
            cache: if True, try to read from local cache before connecting to Redshift.
            kwargs: arguments to be passed to read_sql (e.g., parse_dates=cols)

        Returns:
            A dataframe containing the query results

        Raises:
            AssertionError: data directory or Redshift credentials not found.
        """
        query_hashable = (query + '\n' + str(kwargs)).encode('utf-8')
        query_hash = hashlib.md5(query_hashable).hexdigest()
        fname = os.path.join(self.data_dir, query_hash + '.pickle')

        if not os.path.exists(fname) or not cache:
            print("Attempting to fetch fresh data from DB...")
            con_str = 'postgresql://{user}:{passwd}@{host}:{port}/rsdb'.format(
                **self.conf)
            engine = sqlalchemy.create_engine(con_str)
            df = pd.read_sql(query, con=engine, **kwargs)
            print("Query finished, saving to cache")
            df.to_pickle(fname)
        else:
            print("Loading query results from cache")
            df = pd.read_pickle(fname)
        return df
